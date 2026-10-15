import 'dart:async';

import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/ports.dart';

class MemoryNotes implements NotesRepository {
  final folders = <String, Folder>{};
  final categories = <String, Category>{};
  final notes = <String, Note>{};
  final prefs = <String, String>{};
  final _changes = StreamController<Library>.broadcast(sync: true);
  Library get current => Library(
    folders.values.toList(),
    categories.values.toList(),
    notes.values.toList(),
  );
  void _emit() => _changes.add(current);
  Future<void> close() => _changes.close();
  @override
  Stream<Library> watch() async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<Library> load() async => current;
  @override
  Future<void> save(Note n, {String reason = 'Edición'}) async {
    notes[n.id] = n;
    _emit();
  }

  @override
  Future<void> saveFolder(Folder f) async {
    folders[f.id] = f;
    _emit();
  }

  @override
  Future<void> saveCategory(Category c) async {
    categories[c.id] = c;
    _emit();
  }

  @override
  Future<void> deleteFolder(String id) async {
    folders.remove(id);
    _emit();
  }

  @override
  Future<void> deletePermanently(String id) async {
    notes.remove(id);
    _emit();
  }

  @override
  Future<List<Revision>> history(String id) async => [];
  @override
  Future<void> setPreference(String key, String value) async {
    prefs[key] = value;
  }

  @override
  Future<String?> preference(String key) async => prefs[key];
}
