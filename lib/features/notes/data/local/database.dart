import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
part 'database.g.dart';

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().references(Folders, #id)();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'notes_folder_updated', columns: {#folderId, #updatedAt})
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().references(Folders, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Revisions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get payload => text()();
  DateTimeColumn get savedAt => dateTime()();
}

class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [Folders, Categories, Notes, Revisions, Preferences],
  daos: [LibraryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  factory AppDatabase.file(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file));
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(notes, notes.deletedAt);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

@DriftAccessor(tables: [Folders, Categories, Notes, Revisions, Preferences])
class LibraryDao extends DatabaseAccessor<AppDatabase> with _$LibraryDaoMixin {
  LibraryDao(super.db);
  Future<void> upsertNote(NotesCompanion row, {String? oldSnapshot}) =>
      transaction(() async {
        await into(notes).insertOnConflictUpdate(row);
        if (oldSnapshot != null) {
          await into(revisions).insert(
            RevisionsCompanion.insert(
              noteId: row.id.value,
              payload: oldSnapshot,
              savedAt: DateTime.now().toUtc(),
            ),
          );
          // Keep the latest 50 revisions per note to bound local storage.
          await customStatement(
            'DELETE FROM revisions WHERE note_id = ? AND id NOT IN '
            '(SELECT id FROM revisions WHERE note_id = ? ORDER BY id DESC LIMIT 50)',
            [row.id.value, row.id.value],
          );
        }
      });
}
