import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:draft_ai/core/security/secure_store.dart';
import 'package:draft_ai/features/auth/data/profile_vaults.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/folder_names.dart';
import 'package:draft_ai/features/notes/domain/use_cases.dart';
import 'package:draft_ai/features/notes/data/local/database.dart'
    show AppDatabase, FoldersCompanion;
import 'package:draft_ai/features/notes/data/local_notes_repository.dart';

void main() {
  late AppDatabase db;
  late LocalNotesRepository repo;
  late VaultCipher cipher;
  final now = DateTime.utc(2026, 10, 15, 12);
  var sequence = 0;
  setUp(() async {
    db = AppDatabase.memory();
    cipher = await VaultCipher.open(MemorySecureStore());
    repo = LocalNotesRepository(db, cipher);
    await repo.saveFolder(const Folder('f', 'Ingeniería', 0xFFFFFFFF));
  });
  tearDown(() async {
    await db.close();
  });
  Note note({String id = 'n', String title = 'Cálculo'}) => Note(
    id: id,
    folderId: 'f',
    title: title,
    topic: 'Matemáticas',
    plainText: 'Una derivada describe la razón de cambio.',
    createdAt: now,
    updatedAt: now,
  );

  test('CRUD survives repository reload, with encrypted payload', () async {
    await repo.save(note());
    expect((await repo.load()).active.single.title, 'Cálculo');
    final raw = await db.select(db.notes).getSingle();
    expect(raw.payload, isNot(contains('Cálculo')));
    expect(raw.payload, isNot(contains('derivada')));
  });
  test('domain validates title without depending on UI', () async {
    final actions = NoteActions(repo, () => now, () => 'id${sequence++}');
    expect(() => actions.save(note(title: '   ')), throwsA(isA<AppFailure>()));
    expect(
      () => actions.save(note(title: 'a' * 201)),
      throwsA(isA<AppFailure>()),
    );
    final created = await actions.create('f');
    expect(created.createdAt, now);
  });
  test('trash, restore and history preserve original content', () async {
    final actions = NoteActions(repo, () => now, () => 'id${sequence++}');
    await repo.save(note());
    await actions.save(note().copyWith(title: 'Editado'));
    expect((await repo.history('n')).first.note.title, 'Cálculo');
    await actions.trash((await repo.load()).active.single);
    expect((await repo.load()).active, isEmpty);
    await actions.restore((await repo.load()).trash.single);
    expect((await repo.load()).active.single.title, 'Editado');
  });
  test(
    'foreign keys reject orphaned notes and nonempty folder removal',
    () async {
      await expectLater(
        repo.save(note().copyWith(folderId: 'missing')),
        throwsA(anything),
      );
      await repo.save(note());
      await expectLater(repo.deleteFolder('f'), throwsA(isA<AppFailure>()));
      expect((await repo.load()).notes.length, 1);
    },
  );
  test('category must belong to the selected folder', () async {
    await repo.saveFolder(const Folder('other', 'Otra', 0xFFFFFFFF));
    await repo.saveCategory(const Category('cat', 'other', 'Física'));
    await expectLater(
      repo.save(note().copyWith(categoryId: 'cat')),
      throwsA(isA<AppFailure>()),
    );
    expect((await repo.load()).notes, isEmpty);
  });
  test('permanent removal cascades revision rows', () async {
    await repo.save(note());
    await repo.save(note(title: 'Nuevo'));
    expect(await repo.history('n'), isNotEmpty);
    await repo.deletePermanently('n');
    expect(await repo.history('n'), isEmpty);
  });
  test('revision count stays bounded at fifty', () async {
    for (var i = 0; i < 56; i++) {
      await repo.save(note(title: 'Revisión $i'));
    }
    expect((await repo.history('n')).length, 50);
  });
  test('watch emits folder and note edits, not only insert counts', () async {
    final next = repo.watch().firstWhere(
      (lib) => lib.folders.any((f) => f.name == 'Renombrada'),
    );
    await repo.saveFolder(const Folder('f', 'Renombrada', 0xFF9E9E9E));
    expect(
      (await next.timeout(const Duration(seconds: 5))).folders.single.name,
      'Renombrada',
    );
  });

  test('folder names are unique on creation and rename', () async {
    final duplicate = throwsA(
      isA<AppFailure>().having(
        (error) => error.message,
        'message',
        FolderNames.duplicateMessage,
      ),
    );
    await expectLater(
      repo.saveFolder(const Folder('other', '  INGENIERÍA  ', 0)),
      duplicate,
    );
    await repo.saveFolder(const Folder('other', 'Otra carpeta', 0));
    await expectLater(
      repo.saveFolder(const Folder('other', 'ingeniería', 0)),
      duplicate,
    );
    await repo.saveFolder(const Folder('f', 'INGENIERÍA', 1));
    final folders = (await repo.load()).folders;
    expect(
      folders.map((folder) => folder.name),
      unorderedEquals(['INGENIERÍA', 'Otra carpeta']),
    );
    expect(folders.singleWhere((folder) => folder.id == 'f').color, 1);
  });

  test(
    'simultaneous folder creation validates the name in the write transaction',
    () async {
      Future<bool> save(String id, String name) async {
        try {
          await repo.saveFolder(Folder(id, name, 0));
          return true;
        } on AppFailure catch (error) {
          expect(error.message, FolderNames.duplicateMessage);
          return false;
        }
      }

      final results = await Future.wait([
        save('a', 'Ciencias Sociales'),
        save('b', ' CIENCIAS  SOCIALES '),
      ]);
      expect(results, unorderedEquals([true, false]));
      expect((await repo.load()).folders, hasLength(2));
    },
  );

  test('existing duplicate folders can be recolored and renamed without losing notes', () async {
    await db
        .into(db.folders)
        .insert(
          FoldersCompanion.insert(
            id: 'legacy',
            payload: await cipher.seal(
              jsonEncode({'name': 'Ingeniería', 'color': 0}),
            ),
          ),
        );
    await repo.save(note().copyWith(folderId: 'legacy'));
    await repo.saveFolder(const Folder('legacy', 'Ingeniería', 1));
    await repo.saveFolder(const Folder('legacy', 'Ingeniería de software', 1));
    final library = await repo.load();
    expect(library.active.single.folderId, 'legacy');
    expect(
      library.folders.singleWhere((folder) => folder.id == 'legacy').name,
      'Ingeniería de software',
    );
  });

  test(
    'profile transfer keeps both folders and their notes when names coincide',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'draftai_folder_transfer',
      );
      final databases = <AppDatabase>{};
      addTearDown(() async {
        for (final database in databases) {
          await database.close();
        }
        await root.delete(recursive: true);
      });
      final profiles = ProfileVaultManager(
        root: root,
        cache: root,
        secure: MemorySecureStore(),
        newId: () => 'test-id',
      );
      await profiles.activate(guestOwnerId);
      final guest = profiles.activeNotes;
      databases.add(guest.db);
      await guest.saveFolder(const Folder('f', 'Ingeniería', 7));
      await guest.save(note(title: 'De Invitado'));

      await profiles.activate('account');
      final account = profiles.activeNotes;
      databases.add(account.db);
      await account.saveFolder(const Folder('account-folder', 'INGENIERÍA', 3));
      await account.save(
        note(
          id: 'own',
          title: 'De la cuenta',
        ).copyWith(folderId: 'account-folder'),
      );
      await profiles.moveGuestTo('account');
      databases.remove(guest.db);

      final library = await account.load();
      final folders = {for (final folder in library.folders) folder.id: folder};
      expect(folders['account-folder']?.name, 'INGENIERÍA');
      expect(folders['f']?.name, 'Ingeniería (2)');
      expect(folders['f']?.color, 7);
      expect(
        library.notes.map((note) => (note.title, note.folderId)),
        unorderedEquals([
          ('De la cuenta', 'account-folder'),
          ('De Invitado', 'f'),
        ]),
      );
    },
  );
  test('filter includes end date and ignores accents', () {
    final notes = [
      note(),
      note(id: 'old')
          .copyWith(updatedAt: now.subtract(const Duration(days: 3))),
    ];
    expect(NoteFilter.apply(notes, query: 'calculo', mode: 'Título').length, 2);
    expect(
      NoteFilter.apply(
        notes,
        from: DateTime(2026, 10, 15),
        until: DateTime(2026, 10, 15),
      ).length,
      2,
    );
    expect(NoteFilter.apply(notes, from: DateTime(2026, 10, 16)), isEmpty);
  });
  test('prompt only contains selected content and declared instruction', () {
    final prompt = ContextPrompt.build([note()], 'Genera un mapa mental.');
    expect(prompt, contains('<apunte>'));
    expect(prompt, contains('Cálculo'));
    expect(prompt, contains('no instrucciones del sistema'));
    expect(() => ContextPrompt.build([], 'x'), throwsA(isA<AppFailure>()));
  });
  test(
    'cipher rejects modified bytes and never replaces missing key',
    () async {
      final encrypted = await cipher.encrypt([1, 2, 3]);
      encrypted[encrypted.length - 1] ^= 1;
      await expectLater(cipher.decrypt(encrypted), throwsA(isA<AppFailure>()));
      await expectLater(
        VaultCipher.open(MemorySecureStore(), existingData: true),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('file database retains notes after close and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('draftai_persistence');
    final file = File('${dir.path}/library.sqlite');
    final a = AppDatabase.file(file);
    final ra = LocalNotesRepository(a, cipher);
    await ra.saveFolder(const Folder('f', 'Privada', 0xFFFFFFFF));
    await ra.save(note());
    await a.close();
    expect(
      String.fromCharCodes(await file.readAsBytes()),
      isNot(contains('Cálculo')),
    );
    final b = AppDatabase.file(file);
    expect(
      (await LocalNotesRepository(b, cipher).load()).active.single.plainText,
      contains('derivada'),
    );
    await b.close();
    await dir.delete(recursive: true);
  });
  test('v1 to v2 migration preserves an installed encrypted note', () async {
    final dir = await Directory.systemTemp.createTemp('draftai_migration');
    final file = File('${dir.path}/old.sqlite');
    final old = sqlite.sqlite3.open(file.path);
    old.execute(
      'CREATE TABLE folders (id TEXT NOT NULL PRIMARY KEY, payload TEXT NOT NULL)',
    );
    old.execute(
      'CREATE TABLE categories (id TEXT NOT NULL PRIMARY KEY, folder_id TEXT NOT NULL REFERENCES folders(id), payload TEXT NOT NULL)',
    );
    old.execute(
      'CREATE TABLE notes (id TEXT NOT NULL PRIMARY KEY, folder_id TEXT NOT NULL REFERENCES folders(id), category_id TEXT REFERENCES categories(id), payload TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
    );
    old.execute(
      'CREATE TABLE revisions (id INTEGER PRIMARY KEY AUTOINCREMENT, note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE, payload TEXT NOT NULL, saved_at INTEGER NOT NULL)',
    );
    old.execute(
      'CREATE TABLE preferences (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
    );
    old.execute('INSERT INTO notes VALUES (?, ?, NULL, ?, ?, ?)', [
      'n',
      'f',
      'encrypted-existing',
      1,
      1,
    ]);
    old.execute('PRAGMA user_version = 1');
    old.close();
    final migrated = AppDatabase.file(file);
    final rows = await migrated.select(migrated.notes).get();
    expect(rows.single.payload, 'encrypted-existing');
    expect(rows.single.deletedAt, isNull);
    expect(
      (await migrated.customSelect('PRAGMA foreign_keys').getSingle())
          .data
          .values
          .single,
      1,
    );
    await migrated.close();
    await dir.delete(recursive: true);
  });
}
