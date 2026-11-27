import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/security/secure_store.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import 'direct_ai.dart';

class GatewayAi implements AiService, AiConnection, AiRunMetadata {
  final SecureStore secure;
  final http.Client client;
  final ProfileVaultService profiles;

  DirectAi? _remote;
  DirectAi? _checking;
  String? _loadedOwner;
  AiProvider _provider = AiProvider.custom;
  int _session = 0;
  Future<void> _storage = Future.value();

  GatewayAi(this.secure, this.client, this.profiles);

  static const _changedProfile = AppFailure(
    'El perfil cambió. Vuelve a abrir la conexión de IA.',
  );

  static String _key(String owner) => owner == guestProfileId
      ? 'guest_ai_config_v1'
      : 'account_ai_config_v1_$owner';

  @override
  String? get profileId =>
      _loadedOwner == profiles.activeOwnerId ? _loadedOwner : null;

  DirectAi? get _active => profileId == null ? null : _remote;

  @override
  AiProvider get provider => _active == null ? AiProvider.custom : _provider;

  @override
  bool get configured => _active != null;

  @override
  String get endpoint => _active?.endpoint.toString() ?? '';

  @override
  String get model => _active?.model ?? '';

  Future<void> _queueStorage(Future<void> Function() change) {
    final operation = _storage.then((_) => change());
    _storage = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _deleteKey(String owner) async {
    try {
      await secure.delete(_key(owner));
    } on AppFailure {
      throw const AppFailure(
        'No se pudo borrar la clave de IA del teléfono. Inténtalo de nuevo.',
      );
    }
  }

  bool _isCurrent(String owner, int session) =>
      profiles.activeOwnerId == owner && _session == session;

  int _clearSession() {
    cancel();
    _checking = null;
    _remote = null;
    _loadedOwner = null;
    _provider = AiProvider.custom;
    return ++_session;
  }

  @override
  Future<void> loadProfile() {
    final owner = profiles.activeOwnerId;
    final session = _clearSession();
    return _queueStorage(() async {
      DirectAi? remote;
      var provider = AiProvider.custom;
      try {
        final saved = await secure.read(_key(owner));
        if (saved != null) {
          final json = jsonDecode(saved);
          if (json case {
            'endpoint': final String endpoint,
            'apiKey': final String apiKey,
            'model': final String model,
          }) {
            final selected = AiProvider.values
                .where((value) => value.name == json['provider'])
                .firstOrNull;
            if (selected == null && json.containsKey('provider')) {
              throw const FormatException();
            }
            provider = selected ?? AiProvider.custom;
            final candidate = _buildRemote(
              provider,
              endpoint,
              apiKey.trim(),
              model,
            );
            if (candidate.endpoint == _validateEndpoint(endpoint)) {
              remote = candidate;
            }
          }
        }
      } on FormatException {
        // The form can replace a damaged record.
      } on AppFailure {
        // Notes stay accessible if the stored AI connection cannot be opened.
      }
      if (_isCurrent(owner, session)) {
        _loadedOwner = owner;
        _remote = remote;
        _provider = provider;
      }
    });
  }

  @override
  Future<void> endProfileSession() {
    final owner = profiles.activeOwnerId;
    _clearSession();
    return owner == guestProfileId
        ? _storage
        : _queueStorage(() => _deleteKey(owner));
  }

  @override
  Future<void> connect(
    AiProvider provider,
    String endpoint,
    String apiKey,
    String model,
  ) async {
    final owner = profileId;
    if (owner == null) throw _changedProfile;
    if (_checking != null) {
      throw const AppFailure('Ya se está comprobando una conexión.');
    }

    final (url, name) = _providerSettings(provider, endpoint, model);
    final uri = _validateEndpoint(url);
    final previous = _active;
    final key =
        apiKey.trim().isEmpty &&
            provider == this.provider &&
            previous?.endpoint == uri
        ? previous!.apiKey
        : apiKey.trim();
    final candidate = _buildRemote(provider, url, key, name);
    final session = _session;
    _checking = candidate;
    try {
      await candidate.checkConnection();
      await _queueStorage(() async {
        if (!_isCurrent(owner, session)) throw _changedProfile;
        try {
          await secure.write(
            _key(owner),
            jsonEncode({
              'provider': provider.name,
              'endpoint': candidate.endpoint.toString(),
              'apiKey': candidate.apiKey,
              'model': candidate.model,
            }),
          );
        } on AppFailure {
          throw const AppFailure(
            'No se pudo guardar la clave de IA en el teléfono.',
          );
        }
        if (!_isCurrent(owner, session)) throw _changedProfile;
        _remote?.cancel();
        _remote = candidate;
        _provider = provider;
      });
    } finally {
      if (identical(_checking, candidate)) _checking = null;
    }
  }

  @override
  Future<void> disconnect() async {
    final owner = profileId;
    if (owner == null) throw _changedProfile;
    final session = _clearSession();
    try {
      await _queueStorage(() => _deleteKey(owner));
    } finally {
      if (_isCurrent(owner, session)) await loadProfile();
    }
  }

  DirectAi _buildRemote(
    AiProvider provider,
    String endpoint,
    String apiKey,
    String model,
  ) {
    final (url, name) = _providerSettings(provider, endpoint, model);
    final uri = _validateEndpoint(url);
    if (apiKey.isEmpty) {
      throw const AppFailure('Introduce la clave API de este proveedor.');
    }
    if (apiKey.length > 4096 || apiKey.contains(RegExp(r'\s'))) {
      throw const AppFailure('La clave API no tiene un formato válido.');
    }
    if (name.isEmpty || name.length > 120 || name.contains(RegExp(r'\s'))) {
      throw const AppFailure('Introduce el identificador del modelo.');
    }
    return DirectAi(
      endpoint: uri,
      apiKey: apiKey,
      model: name,
      provider: provider,
      client: client,
    );
  }

  static (String, String) _providerSettings(
    AiProvider provider,
    String endpoint,
    String model,
  ) => switch (provider) {
    AiProvider.openAi => ('https://api.openai.com/v1/', 'gpt-6-luna'),
    AiProvider.claude => ('https://api.anthropic.com/v1/', 'claude-haiku-5-5'),
    AiProvider.gemini => (
      'https://generativelanguage.googleapis.com/v1beta/openai/',
      'gemini-3.1-flash-lite',
    ),
    AiProvider.custom => (endpoint.trim(), model.trim()),
  };

  static Uri _validateEndpoint(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.authority.contains('@') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const AppFailure(
        'Introduce la URL base HTTPS, sin credenciales ni parámetros.',
      );
    }
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }

  @override
  void cancel() {
    _remote?.cancel();
    _checking?.cancel();
  }

  @override
  String get lastModel {
    final remote = _active;
    if (remote == null) return '';
    return remote.lastModel.isEmpty ? remote.model : remote.lastModel;
  }

  @override
  bool get lastWasDemonstration => false;

  Future<T> _run<T>(Future<T> Function(DirectAi) action) async {
    final remote = _active;
    if (remote == null) {
      throw const AppFailure('Conecta un proveedor para usar IA.');
    }
    final result = await action(remote);
    if (!identical(remote, _active)) throw _changedProfile;
    return result;
  }

  @override
  Future<String> transform(String text, AiAction action) =>
      _run((remote) => remote.transform(text, action));

  @override
  Future<List<AiQuizQuestion>> generateQuiz(String text) =>
      _run((remote) => remote.generateQuiz(text));

  @override
  Future<AnalysisProposal> analyze(List<PickedFile> files, Library library) =>
      _run((remote) => remote.analyze(files, library));
}
