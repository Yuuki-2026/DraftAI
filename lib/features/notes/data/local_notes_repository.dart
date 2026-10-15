import 'dart:convert';

import 'package:drift/drift.dart' show Value, OrderingTerm, OrderingMode;

import '../../../core/security/secure_store.dart';
import '../domain/entities.dart' as domain;
import '../domain/ports.dart';
import 'local/database.dart';
import 'note_mapper.dart';

class LocalNotesRepository implements NotesRepository {
  final AppDatabase db;
  final VaultCipher cipher;
  LocalNotesRepository(this.db, this.cipher);
  @override
  Stream<domain.Library> watch() => db
      .customSelect(
        'SELECT (SELECT COUNT(*) FROM notes) AS n',
        readsFrom: {db.notes, db.folders, db.categories},
      )
      .watch()
      .asyncMap((_) => load());

  @override
  Future<domain.Library> load() async {
    final folders = <domain.Folder>[];
    for (final row in await db.select(db.folders).get()) {
      final j =
          jsonDecode(await cipher.unseal(row.payload)) as Map<String, dynamic>;
      folders.add(
        domain.Folder(row.id, j['name'] as String, j['color'] as int),
      );
    }
    final categories = <domain.Category>[];
    for (final row in await db.select(db.categories).get()) {
      categories.add(
        domain.Category(row.id, row.folderId, await cipher.unseal(row.payload)),
      );
    }
    final notes = <domain.Note>[];
    for (final row in await db.select(db.notes).get()) {
      notes.add(NoteMapper.decode(await cipher.unseal(row.payload)));
    }
    return domain.Library(folders, categories, notes);
  }

  @override
  Future<void> save(domain.Note note, {String reason = 'Edición'}) async {
    final old = await (db.select(
      db.notes,
    )..where((n) => n.id.equals(note.id))).getSingleOrNull();
    if (note.categoryId != null) {
      final cat = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(note.categoryId!))).getSingleOrNull();
      if (cat == null || cat.folderId != note.folderId) {
        throw const domain.AppFailure(
          'La categoría no pertenece a esta carpeta.',
        );
      }
    }
    final snapshot = old == null
        ? null
        : await cipher.seal(
            jsonEncode({
              'reason': reason,
              'note': await cipher.unseal(old.payload),
            }),
          );
    await db.libraryDao.upsertNote(
      NotesCompanion.insert(
        id: note.id,
        folderId: note.folderId,
        categoryId: Value(note.categoryId),
        payload: await cipher.seal(NoteMapper.encode(note)),
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        deletedAt: Value(note.deletedAt),
      ),
      oldSnapshot: snapshot,
    );
  }

  @override
  Future<void> saveFolder(domain.Folder f) async {
    if (f.name.trim().isEmpty || f.name.length > 80) {
      throw const domain.AppFailure(
        'La carpeta debe tener entre 1 y 80 caracteres.',
      );
    }
    await db
        .into(db.folders)
        .insertOnConflictUpdate(
          FoldersCompanion.insert(
            id: f.id,
            payload: await cipher.seal(
              jsonEncode({'name': f.name.trim(), 'color': f.color}),
            ),
          ),
        );
  }

  @override
  Future<void> saveCategory(domain.Category c) async {
    if (c.name.trim().isEmpty || c.name.length > 80) {
      throw const domain.AppFailure(
        'Escribe una categoría de hasta 80 caracteres.',
      );
    }
    await db
        .into(db.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: c.id,
            folderId: c.folderId,
            payload: await cipher.seal(c.name.trim()),
          ),
        );
  }

  @override
  Future<void> deleteFolder(String id) async {
    if (await (db.select(
      db.notes,
    )..where((n) => n.folderId.equals(id))).get().then((v) => v.isNotEmpty)) {
      throw const domain.AppFailure(
        'Mueve o elimina definitivamente los apuntes de esta carpeta primero.',
      );
    }
    await db.transaction(() async {
      await (db.delete(
        db.categories,
      )..where((c) => c.folderId.equals(id))).go();
      await (db.delete(db.folders)..where((f) => f.id.equals(id))).go();
    });
  }

  @override
  Future<void> deletePermanently(String id) async {
    await (db.delete(db.notes)..where((n) => n.id.equals(id))).go();
  }

  @override
  Future<List<domain.Revision>> history(String id) async {
    final rows =
        await (db.select(db.revisions)
              ..where((r) => r.noteId.equals(id))
              ..orderBy([
                (r) => OrderingTerm(expression: r.id, mode: OrderingMode.desc),
              ]))
            .get();
    final result = <domain.Revision>[];
    for (final row in rows) {
      final j =
          jsonDecode(await cipher.unseal(row.payload)) as Map<String, dynamic>;
      result.add(
        domain.Revision(
          row.id,
          NoteMapper.decode(j['note'] as String),
          j['reason'] as String,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> setPreference(String key, String value) => db
      .into(db.preferences)
      .insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: value),
      );
  @override
  Future<String?> preference(String key) async => (await (db.select(
    db.preferences,
  )..where((p) => p.key.equals(key))).getSingleOrNull())?.value;
}
