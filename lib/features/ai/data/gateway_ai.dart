import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/security/secure_store.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import 'ai_services.dart';
import 'guest_openai.dart';

/// Routes Google sessions to the managed Azure API and Guest sessions to the
/// provider configured by that guest on this device.
class GatewayAi
    implements AiService, AiConnection, AiRunMetadata, AiAccessProvider {
  final SecureStore secure;
  final http.Client client;
  final IdentityService identity;
  RemoteAi? _googleRemote;
  GuestOpenAi? _guestRemote;
  Uri? _googleEndpoint;
  Uri? _guestEndpoint;
  String _guestApiKey = '';
  String _guestModel = '';

  GatewayAi(this.secure, this.client, this.identity);

  Future<void> initialize() async {
    final cloudEndpoint = const String.fromEnvironment('AI_BASE_URL').trim();
    final cloudUri = Uri.tryParse(cloudEndpoint);
    if (cloudUri != null &&
        cloudUri.scheme == 'https' &&
        cloudUri.host.isNotEmpty &&
        cloudUri.userInfo.isEmpty &&
        cloudUri.query.isEmpty &&
        cloudUri.fragment.isEmpty) {
      final base = _asBaseUri(cloudUri);
      _googleEndpoint = base;
      _googleRemote = RemoteAi(base, identity, client);
    }

    final saved = await secure.read('guest_ai_config_v1');
    if (saved == null || saved.isEmpty) return;
    try {
      final value = jsonDecode(saved);
      if (value is! Map<String, dynamic>) return;
      final endpoint = value['endpoint'];
      final apiKey = value['apiKey'];
      final model = value['model'];
      if (endpoint is! String || apiKey is! String || model is! String) return;
      final uri = _validateEndpoint(endpoint);
      if (apiKey.trim().isEmpty || !_validModel(model)) return;
      _guestEndpoint = uri;
      _guestApiKey = apiKey;
      _guestModel = model.trim();
      _guestRemote = _createGuestRemote();
    } catch (_) {
      // Keep malformed credentials unavailable without replacing them; the
      // guest can reopen setup and save a valid configuration.
    }
  }

  bool get _googleSession =>
      identity is AccountIdentityService &&
      (identity as AccountIdentityService).userId != null;

  @override
  bool get isGoogleAccount => _googleSession;

  @override
  bool get usesGoogleCloud => _googleSession;

  AiService? get _activeService =>
      _googleSession ? _googleRemote : _guestRemote;

  String get _configurationFailure => _googleSession
      ? 'El servicio de IA de tu cuenta todavía no está disponible. El backend de Azure debe estar configurado.'
      : 'Configura un proveedor compatible con OpenAI para usar IA en Invitado.';

  @override
  bool get configured => _activeService?.configured ?? false;

  @override
  bool get canDisconnect => !_googleSession && _guestRemote != null;

  @override
  String get endpoint => _googleSession
      ? _googleEndpoint?.toString() ?? ''
      : _guestEndpoint?.toString() ?? '';

  @override
  String get model => _googleSession
      ? (_googleRemote?.lastModel.isNotEmpty == true
            ? _googleRemote!.lastModel
            : 'IA en la nube')
      : _guestModel;

  @override
  Future<void> connect(String endpoint, String apiKey, String model) async {
    if (_googleSession) {
      throw const AppFailure(
        'Las cuentas de Google usan el servicio de IA de DraftAI; no configuran una clave propia.',
      );
    }
    final uri = _validateEndpoint(endpoint);
    final key = apiKey.trim().isEmpty ? _guestApiKey : apiKey.trim();
    final selectedModel = model.trim();
    if (key.isEmpty) {
      throw const AppFailure('Introduce la clave API de tu proveedor.');
    }
    if (key.length > 4096 || key.contains(RegExp(r'\s'))) {
      throw const AppFailure('La clave API no tiene un formato válido.');
    }
    if (!_validModel(selectedModel)) {
      throw const AppFailure('Introduce el identificador del modelo.');
    }

    // Store the three values in one secure record so a partial write cannot
    // leave a mismatched endpoint and credential behind.
    await secure.write(
      'guest_ai_config_v1',
      jsonEncode({
        'endpoint': uri.toString(),
        'apiKey': key,
        'model': selectedModel,
      }),
    );
    _guestEndpoint = uri;
    _guestApiKey = key;
    _guestModel = selectedModel;
    _guestRemote = _createGuestRemote();
  }

  @override
  Future<void> disconnect() async {
    if (_googleSession) {
      throw const AppFailure(
        'La conexión de IA de Google se administra desde DraftAI.',
      );
    }
    _guestRemote?.cancel();
    await secure.delete('guest_ai_config_v1');
    _guestRemote = null;
    _guestEndpoint = null;
    _guestApiKey = '';
    _guestModel = '';
  }

  GuestOpenAi _createGuestRemote() => GuestOpenAi(
    endpoint: _guestEndpoint!,
    apiKey: _guestApiKey,
    model: _guestModel,
    client: client,
  );

  static Uri _validateEndpoint(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const AppFailure(
        'Introduce la URL base HTTPS del proveedor, sin clave ni parámetros.',
      );
    }
    return _asBaseUri(uri);
  }

  static Uri _asBaseUri(Uri uri) => uri.replace(
    path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    query: '',
    fragment: '',
  );

  static bool _validModel(String value) =>
      value.trim().isNotEmpty &&
      value.trim().length <= 120 &&
      !value.contains(RegExp(r'\s'));

  @override
  void cancel() {
    _googleRemote?.cancel();
    _guestRemote?.cancel();
  }

  AiService _requireActive() {
    final service = _activeService;
    if (service == null) throw AppFailure(_configurationFailure);
    return service;
  }

  @override
  String get lastModel {
    final service = _activeService;
    if (service is AiRunMetadata && service.lastModel.isNotEmpty) {
      return service.lastModel;
    }
    return model;
  }

  @override
  bool get lastWasDemonstration => false;

  @override
  Future<String> transform(String text, AiAction action) =>
      _requireActive().transform(text, action);

  @override
  Future<List<AiQuizQuestion>> generateQuiz(String text) =>
      _requireActive().generateQuiz(text);

  @override
  Future<AnalysisProposal> analyze(List<PickedFile> files, Library library) =>
      _requireActive().analyze(files, library);

  @override
  Future<AiAccess> refreshAccess() async {
    if (_googleSession) {
      final remote = _googleRemote;
      if (remote == null) throw AppFailure(_configurationFailure);
      return remote.refreshAccess();
    }
    final guest = _guestRemote;
    if (guest == null) throw AppFailure(_configurationFailure);
    // The external provider owns its limits. A zero app limit marks this access
    // as provider-managed; the controller must not enforce DraftAI's quota.
    return AiAccess(
      pro: false,
      vision: true,
      model: _guestModel,
      remaining: 1 << 30,
      limit: 0,
      used: 0,
    );
  }
}
