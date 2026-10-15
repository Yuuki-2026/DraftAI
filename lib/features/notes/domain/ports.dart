import 'dart:typed_data';

import 'entities.dart';

abstract interface class NotesRepository {
  Stream<Library> watch();
  Future<Library> load();
  Future<void> save(Note note, {String reason = 'Edición'});
  Future<void> saveFolder(Folder folder);
  Future<void> saveCategory(Category category);
  Future<void> deleteFolder(String id);
  Future<void> deletePermanently(String id);
  Future<List<Revision>> history(String id);
  Future<void> setPreference(String key, String value);
  Future<String?> preference(String key);
}

abstract interface class MediaRepository {
  Future<List<PickedFile>> pick(CaptureSource source);
  Future<Attachment> store(PickedFile file);
  Future<Uint8List> read(Attachment attachment);
  Future<void> delete(Attachment attachment);
  Future<int> storageBytes();
  Future<int> clearCache();
}

abstract interface class ExportService {
  Future<void> export(List<Note> notes, ExportFormat format);
  Future<void> backup(Library library);
}

abstract interface class SpeechService {
  Future<bool> listen(void Function(String) onResult);
  Future<void> stop();
}

class AnalysisProposal {
  final String text, summary, title, topic, folderName, categoryName;
  final bool demonstration;
  const AnalysisProposal({
    required this.text,
    required this.summary,
    required this.title,
    required this.topic,
    required this.folderName,
    this.categoryName = '',
    this.demonstration = false,
  });
}

abstract interface class AiService {
  bool get configured;
  Future<String> transform(String text, AiAction action);
  Future<AnalysisProposal> analyze(List<PickedFile> files, Library library);
}

abstract interface class IdentityService {
  bool get configured;
  String? get displayName;
  Future<void> signIn();
  Future<void> signOut();
  Future<String?> idToken();
}
