import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/security/secure_store.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import 'ai_services.dart';

class GatewayAi implements AiService, AiConnection {
  final SecureStore secure;
  final http.Client client;
  RemoteAi? _remote;
  String _endpoint = '', _model = 'openai/gpt-oss-20b';
  GatewayAi(this.secure, this.client);
  Future<void> initialize() async {
    _endpoint =
        await secure.read('test_ai_endpoint') ??
        const String.fromEnvironment('AI_BASE_URL');
    final token = await secure.read('test_ai_device_token') ?? '';
    if (_endpoint.isNotEmpty && token.isNotEmpty) {
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
      ..body = jsonEncode({'code': code.trim()});
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const AppFailure(
          'No se pudo conectar. Revisa el código y que el servidor esté encendido.',
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
      _model = value['model'] is String ? value['model'] as String : _model;
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
  }

  @override
  void cancel() => _remote?.cancel();
  @override
  Future<String> transform(String text, AiAction action) =>
      (_remote ?? DemonstrationAi()).transform(text, action);
  @override
  Future<AnalysisProposal> analyze(List<PickedFile> files, Library library) =>
      (_remote ?? DemonstrationAi()).analyze(files, library);
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
