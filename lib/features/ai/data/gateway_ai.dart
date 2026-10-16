import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/security/secure_store.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import 'ai_services.dart';

class GatewayAi
    implements AiService, AiConnection, AiRunMetadata, AiAccessProvider {
  final SecureStore secure;
  final http.Client client;
  RemoteAi? _remote;
  String _endpoint = '', _model = 'openai/gpt-oss-20b';
  GatewayAi(this.secure, this.client);
  Future<void> initialize() async {
    _endpoint =
        await secure.read('test_ai_endpoint') ??
        const String.fromEnvironment('AI_BASE_URL');
    _model = await secure.read('test_ai_model') ?? _model;
    final token = await secure.read('test_ai_device_token') ?? '';
    final expires = int.tryParse(await secure.read('test_ai_expires') ?? '');
    if (_endpoint.isNotEmpty &&
        RegExp(r'^[a-f0-9]{64}$').hasMatch(token) &&
        (expires == null || expires > DateTime.now().millisecondsSinceEpoch)) {
      _remote = RemoteAi(Uri.parse(_endpoint), _DeviceIdentity(token), client);
    }
  }

  @override
  String get endpoint => _endpoint;
  @override
  String get model => _model;
  @override
  bool get configured => _remote != null;
  @override
  Future<void> connect(String endpoint, String code) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const AppFailure('Introduce una dirección HTTPS válida.');
    }
    if (!RegExp(r'^[a-fA-F0-9]{18}$').hasMatch(code.trim())) {
      throw const AppFailure(
        'Introduce el código de conexión de 18 caracteres.',
      );
    }
    final base = uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
      query: '',
      fragment: '',
    );
    final request = http.Request('POST', base.resolve('v1/pair'))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'code': code.trim(),
        if (Uri.tryParse(_endpoint)?.host == base.host)
          'previousToken': await secure.read('test_ai_device_token') ?? '',
      });
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        final failure = jsonDecode(response.body);
        final message = failure is Map ? failure['error'] : null;
        throw AppFailure(
          message is String && message.length <= 300
              ? message
              : 'No se pudo conectar al servidor de prueba.',
        );
      }
      final value = jsonDecode(response.body) as Map;
      final token = value['token'];
      if (token is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
        throw const FormatException();
      }
      await secure.write('test_ai_endpoint', base.toString());
      await secure.write('test_ai_device_token', token);
      _endpoint = base.toString();
      _model = value['model'] as String? ?? _model;
      await secure.write('test_ai_model', _model);
      await secure.write(
        'test_ai_expires',
        (value['expires'] as num? ??
                DateTime.now()
                    .add(const Duration(hours: 24))
                    .millisecondsSinceEpoch)
            .toString(),
      );
      _remote = RemoteAi(base, _DeviceIdentity(token), client);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('No se pudo conectar al servidor de prueba.');
    }
  }

  @override
  Future<void> disconnect() async {
    _remote?.cancel();
    await secure.write('test_ai_device_token', '');
    _remote = null;
    _model = '';
    await secure.write('test_ai_model', '');
    await secure.write('test_ai_expires', '0');
  }

  @override
  void cancel() => _remote?.cancel();
  @override
  String get lastModel =>
      _remote?.lastModel.isNotEmpty == true ? _remote!.lastModel : _model;
  @override
  bool get lastWasDemonstration => false;
  @override
  Future<String> transform(String text, AiAction action) async {
    final remote = _remote;
    if (remote == null) {
      throw const AppFailure(
        'Conecta la IA antes de procesar texto. No se ha consultado ningún modelo.',
      );
    }
    return remote.transform(text, action);
  }

  @override
  Future<AnalysisProposal> analyze(
    List<PickedFile> files,
    Library library,
  ) async {
    final remote = _remote;
    if (remote == null) {
      throw const AppFailure('Conecta la IA antes de analizar las fuentes.');
    }
    return remote.analyze(files, library);
  }

  @override
  Future<AiAccess> refreshAccess() async {
    if (_remote == null) throw const AppFailure('Conecta la IA de prueba.');
    final access = await _remote!.refreshAccess();
    _model = access.model;
    await secure.write('test_ai_model', _model);
    return access;
  }
}

class _DeviceIdentity implements IdentityService {
  final String token;
  _DeviceIdentity(this.token);
  @override
  bool get configured => true;
  @override
  String? get displayName => null;
  @override
  Future<String?> idToken() async => token;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
}
