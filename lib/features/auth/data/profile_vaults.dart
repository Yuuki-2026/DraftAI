import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/security/secure_store.dart';
import '../../capture/data/local_media_repository.dart';
import '../../notes/data/note_mapper.dart';
import '../../notes/data/local/database.dart' show AppDatabase;
import '../../notes/data/local_notes_repository.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/note_document.dart';
import '../../notes/domain/ports.dart';

const guestOwnerId = guestProfileId;

class _ProfileVault {
  final String keyName;
  final AppDatabase database;
  final LocalNotesRepository notes;
  final LocalMediaRepository media;

  const _ProfileVault({
    required this.keyName,
    required this.database,
    required this.notes,
    required this.media,
  });
}

/// Opens one independently encrypted local library for the guest and each UID.
class ProfileVaultManager implements ProfileVaultService {
  final Directory root, cache;
  final SecureStore secure;
  final String Function() newId;
  final Map<String, _ProfileVault> _opened = {};
  String _activeOwnerId = guestOwnerId;

  ProfileVaultManager({
    required this.root,
    required this.cache,
    required this.secure,
    required this.newId,
  });

  @override
  String get activeOwnerId => _activeOwnerId;

  _ProfileVault get _active => _opened[_activeOwnerId]!;
  LocalNotesRepository get activeNotes => _active.notes;
  LocalMediaRepository get activeMedia => _active.media;

  String _segment(String ownerId) => ownerId == guestOwnerId
      ? guestOwnerId
      : 'u_${base64Url.encode(utf8.encode(ownerId)).replaceAll('=', '')}';

  Future<_ProfileVault> _open(String ownerId) async {
    final existing = _opened[ownerId];
    if (existing != null) return existing;
    final segment = _segment(ownerId);
    final guest = ownerId == guestOwnerId;
    final directory = guest
        ? root
        : Directory(p.join(root.path, 'profiles', segment));
    await directory.create(recursive: true);
    final databaseFile = File(
      p.join(directory.path, guest ? 'draftai.sqlite' : 'library.sqlite'),
    );
    final mediaDirectory = Directory(
      guest ? p.join(root.path, 'media') : p.join(directory.path, 'media'),
    );
    final keyName = guest ? 'vault_key_v1' : 'vault_key_$segment';
    final hasMedia =
        await mediaDirectory.exists() && !await mediaDirectory.list().isEmpty;
    final vault = await VaultCipher.open(
      secure,
      keyName: keyName,
      existingData: await databaseFile.exists() || hasMedia,
    );
    final database = AppDatabase.file(databaseFile);
    final context = _ProfileVault(
      keyName: keyName,
      database: database,
      notes: LocalNotesRepository(database, vault),
      media: LocalMediaRepository(mediaDirectory, cache, vault, newId),
    );
    _opened[ownerId] = context;
    return context;
  }

  @override
  Future<void> activate(String ownerId) async {
    if (ownerId.trim().isEmpty) {
      throw const AppFailure('No se pudo identificar esta cuenta de Google.');
    }
    await _open(ownerId);
    _activeOwnerId = ownerId;
  }

  @override
  Future<int> guestNoteCount() async =>
      (await _open(guestOwnerId)).notes.noteCount();

  @override
  Future<bool> guestMovePromptEnabled() async =>
      (await _open(guestOwnerId)).notes.preference('guest_move_prompt') !=
      'false';

  @override
  Future<void> setGuestMovePromptEnabled(bool enabled) async =>
      (await _open(guestOwnerId)).notes
          .setPreference('guest_move_prompt', enabled ? 'true' : 'false');

  @override
  Future<void> moveGuestTo(String ownerId) async {
    if (ownerId == guestOwnerId || ownerId.trim().isEmpty) {
      throw const AppFailure('No se pudo identificar la cuenta de destino.');
    }
    final source = await _open(guestOwnerId);
    final target = await _open(ownerId);
    final sourceLibrary = await source.notes.load();
    final targetLibrary = await target.notes.load();
    final targetNotes = {for (final n in targetLibrary.notes) n.id: n};

    for (final folder in sourceLibrary.folders) {
      await target.notes.saveFolder(folder);
    }
    for (final category in sourceLibrary.categories) {
      await target.notes.saveCategory(category);
    }

    final movedAttachments = <String, Attachment>{};
    for (final note in sourceLibrary.notes) {
      final copy = await _copyNote(note, source, target, movedAttachments);
      if (!targetNotes.containsKey(note.id)) {
        await target.notes.save(copy, reason: 'Traslado desde Invitado');
      }
      targetNotes[note.id] = copy;

      // Preserve note history too. Processing oldest first makes a retry
      // continue after the snapshots already committed to the destination.
      final history = await source.notes.history(note.id);
      final targetHistory = await target.notes.history(note.id);
      if (targetHistory.length > history.length) {
        throw const AppFailure(
          'El historial de destino no coincide. Los apuntes de Invitado siguen intactos.',
        );
      }
      final oldestFirst = history.reversed.toList();
      for (var i = 0; i < targetHistory.length; i++) {
        final sourceRevision = oldestFirst[i];
        final expectedRevision = await _copyNote(
          sourceRevision.note,
          source,
          target,
          movedAttachments,
        );
        final copiedRevision = targetHistory[targetHistory.length - 1 - i];
        if (sourceRevision.reason != copiedRevision.reason ||
            NoteMapper.encode(expectedRevision) !=
                NoteMapper.encode(copiedRevision.note)) {
          throw const AppFailure(
            'No se pudo verificar una versión del historial. Los apuntes de Invitado siguen intactos.',
          );
        }
      }
      for (var i = targetHistory.length; i < history.length; i++) {
        final revision = oldestFirst[i];
        final copy = await _copyNote(
          revision.note,
          source,
          target,
          movedAttachments,
        );
        await target.notes.saveRevisionSnapshot(copy, reason: revision.reason);
      }
    }

    final verified = await target.notes.load();
    final verifiedFolders = {
      for (final folder in verified.folders) folder.id: folder,
    };
    final verifiedCategories = {
      for (final category in verified.categories) category.id: category,
    };
    final verifiedNotes = {for (final n in verified.notes) n.id: n};
    if (!sourceLibrary.folders.every((folder) {
          final copied = verifiedFolders[folder.id];
          return copied != null &&
              copied.name == folder.name &&
              copied.color == folder.color;
        }) ||
        !sourceLibrary.categories.every((category) {
          final copied = verifiedCategories[category.id];
          return copied != null &&
              copied.folderId == category.folderId &&
              copied.name == category.name;
        }) ||
        !sourceLibrary.notes.every((n) => verifiedNotes.containsKey(n.id))) {
      throw const AppFailure(
        'No se pudo verificar todo el traslado. Tus apuntes de Invitado siguen intactos; vuelve a intentarlo.',
      );
    }
    for (final original in sourceLibrary.notes) {
      final copied = verifiedNotes[original.id]!;
      final expected = await _copyNote(
        original,
        source,
        target,
        movedAttachments,
      );
      if (NoteMapper.encode(expected) != NoteMapper.encode(copied)) {
        throw const AppFailure(
          'No se pudo verificar el contenido de un apunte. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.',
        );
      }
      final sourceHistory = await source.notes.history(original.id);
      final targetHistory = await target.notes.history(original.id);
      if (targetHistory.length != sourceHistory.length) {
        throw const AppFailure(
          'No se pudo verificar el historial de un apunte. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.',
        );
      }
      for (var i = 0; i < sourceHistory.length; i++) {
        final sourceRevision = sourceHistory[sourceHistory.length - 1 - i];
        final expectedRevision = await _copyNote(
          sourceRevision.note,
          source,
          target,
          movedAttachments,
        );
        final copiedRevision = targetHistory[i];
        if (sourceRevision.reason != copiedRevision.reason ||
            NoteMapper.encode(expectedRevision) !=
                NoteMapper.encode(copiedRevision.note)) {
          throw const AppFailure(
            'No se pudo verificar el contenido del historial. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.',
          );
        }
      }
    }

    // The guest copy is removed only after all rows and encrypted attachments
    // have been reopened and verified from the destination vault.
    await source.notes.setPreference('entered', 'false');
    await source.notes.clearLibrary();
    await source.media.clearAll();
    await source.database.close();
    _opened.remove(guestOwnerId);
    // Keep the empty guest database/preferences, but protect future guest data
    // with a fresh key so the transferred account key cannot open it.
    try {
      await VaultCipher.rotate(secure, keyName: source.keyName);
    } catch (_) {
      // Migration is already verified and the guest payloads are gone. Keeping
      // the old key is safer than reporting a failed move after deleting data.
    }
  }

  Future<Note> _copyNote(
    Note note,
    _ProfileVault source,
    _ProfileVault target,
    Map<String, Attachment> movedAttachments,
  ) async {
    final attachments = <Attachment>[];
    for (final attachment in note.attachments) {
      var copy = movedAttachments[attachment.id];
      if (copy == null) {
        final bytes = await source.media.read(attachment);
        copy = Attachment(
          'g_${attachment.id}',
          attachment.name,
          attachment.mime,
        );
        try {
          final existingBytes = await target.media.read(copy);
          if (!_sameBytes(bytes, existingBytes)) {
            throw const AppFailure(
              'Un archivo de destino no coincide con el original. Los apuntes de Invitado siguen intactos.',
            );
          }
        } on AppFailure catch (error) {
          if (error.message.contains('no coincide')) rethrow;
          copy = await target.media.storeWithId(
            PickedFile(attachment.name, attachment.mime, bytes),
            copy.id,
          );
        }
        final reopenedBytes = await target.media.read(copy);
        if (!_sameBytes(bytes, reopenedBytes)) {
          throw const AppFailure(
            'No se pudo verificar un archivo trasladado. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.',
          );
        }
        movedAttachments[attachment.id] = copy;
      }
      attachments.add(copy);
    }
    return note.copyWith(
      attachments: attachments,
      document: _remapDocument(note.document, movedAttachments),
    );
  }

  String _remapDocument(String document, Map<String, Attachment> mapping) {
    if (document.isEmpty) return document;
    try {
      final decoded = jsonDecode(document);
      if (decoded is! List) {
        throw const FormatException('Documento no válido.');
      }
      final operations = decoded.map((value) {
        if (value is! Map) throw const FormatException('Operación no válida.');
        final operation = Map<String, dynamic>.from(value);
        final insert = operation['insert'];
        if (insert is Map && insert.containsKey(NoteDocument.mediaKey)) {
          final originalId = NoteDocument.mediaId(
            insert[NoteDocument.mediaKey],
          );
          final replacement = originalId == null ? null : mapping[originalId];
          if (replacement == null) {
            throw const FormatException('Falta un archivo adjunto.');
          }
          operation['insert'] = {
            ...Map<String, dynamic>.from(insert),
            NoteDocument.mediaKey: NoteDocument.mediaData(
              replacement.id,
              width: NoteDocument.mediaWidth(insert[NoteDocument.mediaKey]),
              alignment: NoteDocument.mediaAlignment(
                insert[NoteDocument.mediaKey],
              ),
            ),
          };
        }
        return operation;
      }).toList();
      return jsonEncode(operations);
    } on FormatException {
      throw const AppFailure(
        'El contenido de un apunte no se pudo trasladar. Tus datos de Invitado siguen intactos.',
      );
    }
  }

  bool _sameBytes(Uint8List first, Uint8List second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}

class ProfiledNotesRepository implements NotesRepository {
  final ProfileVaultManager vaults;
  ProfiledNotesRepository(this.vaults);
  LocalNotesRepository get _notes => vaults.activeNotes;

  @override
  Stream<Library> watch() => _notes.watch();
  @override
  Future<Library> load() => _notes.load();
  @override
  Future<void> save(Note note, {String reason = 'Edición'}) =>
      _notes.save(note, reason: reason);
  @override
  Future<void> saveFolder(Folder folder) => _notes.saveFolder(folder);
  @override
  Future<void> saveCategory(Category category) => _notes.saveCategory(category);
  @override
  Future<void> deleteFolder(String id) => _notes.deleteFolder(id);
  @override
  Future<void> deletePermanently(String id) => _notes.deletePermanently(id);
  @override
  Future<List<Revision>> history(String id) => _notes.history(id);
  @override
  Future<void> setPreference(String key, String value) =>
      _notes.setPreference(key, value);
  @override
  Future<String?> preference(String key) => _notes.preference(key);
}

class ProfiledMediaRepository implements MediaRepository {
  final ProfileVaultManager vaults;
  ProfiledMediaRepository(this.vaults);
  LocalMediaRepository get _media => vaults.activeMedia;

  @override
  Future<List<PickedFile>> pick(CaptureSource source) => _media.pick(source);
  @override
  Future<Attachment> store(PickedFile file) => _media.store(file);
  @override
  Future<Uint8List> read(Attachment attachment) => _media.read(attachment);
  @override
  Future<void> delete(Attachment attachment) => _media.delete(attachment);
  @override
  Future<int> storageBytes() => _media.storageBytes();
  @override
  Future<int> clearCache() => _media.clearCache();
}
