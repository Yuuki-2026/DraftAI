import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/notes/domain/entities.dart';

abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SystemSecureStore implements SecureStore {
  // A keychain error must never silently replace a key and orphan existing notes.
  final _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'draftai_v1',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'pe.edu.uandina.draft_ai',
      synchronizable: false,
    ),
  );
  @override
  Future<String?> read(String key) async {
    try {
      return await _store.read(key: key);
    } catch (_) {
      throw const AppFailure(
        'No se pudo abrir el almacén seguro. Desbloquea el dispositivo y vuelve a intentar.',
      );
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _store.write(key: key, value: value);
    } catch (_) {
      throw const AppFailure('No se pudo proteger la clave de los apuntes.');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _store.delete(key: key);
    } catch (_) {
      throw const AppFailure('No se pudo retirar la clave de los apuntes.');
    }
  }
}

class MemorySecureStore implements SecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class VaultCipher {
  final AesGcm _algorithm = AesGcm.with256bits();
  final SecretKey _key;
  VaultCipher(this._key);
  static Future<VaultCipher> open(
    SecureStore store, {
    bool existingData = false,
    String keyName = 'vault_key_v1',
  }) async {
    var encoded = await store.read(keyName);
    if (encoded == null) {
      if (existingData) {
        throw const AppFailure(
          'Falta la clave de los datos existentes. No se reemplazará ni borrará tu biblioteca.',
        );
      }
      final key = await AesGcm.with256bits().newSecretKey();
      encoded = base64Encode(await key.extractBytes());
      await store.write(keyName, encoded);
    }
    return VaultCipher(SecretKey(base64Decode(encoded)));
  }

  static Future<void> rotate(
    SecureStore store, {
    String keyName = 'vault_key_v1',
  }) async {
    final key = await AesGcm.with256bits().newSecretKey();
    await store.write(keyName, base64Encode(await key.extractBytes()));
  }

  Future<String> seal(String value) async =>
      base64Encode(await encrypt(utf8.encode(value)));
  Future<String> unseal(String value) async =>
      utf8.decode(await decrypt(base64Decode(value)));
  Future<List<int>> encrypt(List<int> bytes) async {
    final box = await _algorithm.encrypt(bytes, secretKey: _key);
    return box.concatenation();
  }

  Future<List<int>> decrypt(List<int> bytes) async {
    try {
      return await _algorithm.decrypt(
        SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16),
        secretKey: _key,
      );
    } catch (_) {
      throw const AppFailure(
        'No se pudo verificar la integridad del contenido cifrado.',
      );
    }
  }
}
