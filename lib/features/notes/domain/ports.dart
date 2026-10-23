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

abstract interface class ConfigurableExportService implements ExportService {
  Future<void> exportConfigured({
    required List<Note> notes,
    required ExportFormat format,
    required ExportOptions options,
    required bool separateFiles,
  });
}

abstract interface class SpeechService {
  Future<bool> listen(void Function(String) onResult);
  Future<void> stop();
}

class AnalysisProposal {
  final String text,
      summary,
      title,
      topic,
      folderName,
      categoryName,
      model,
      folderId,
      noteId,
      noteTitle,
      reason;
  final bool demonstration, academic, readable, partial;
  final int sourceIndex;
  final List<AnalysisProposal> items;
  const AnalysisProposal({
    required this.text,
    required this.summary,
    required this.title,
    required this.topic,
    required this.folderName,
    this.categoryName = '',
    this.model = '',
    this.folderId = '',
    this.noteId = '',
    this.noteTitle = '',
    this.reason = '',
    this.demonstration = false,
    this.academic = true,
    this.readable = true,
    this.partial = false,
    this.sourceIndex = 0,
    this.items = const [],
  });
}

class AiAccess {
  final bool pro, vision;
  final String model;
  final int remaining, limit, used, globalRemaining, globalLimit;
  const AiAccess({
    required this.pro,
    required this.vision,
    required this.model,
    required this.remaining,
    this.limit = 0,
    this.used = 0,
    this.globalRemaining = -1,
    this.globalLimit = 0,
  });
}

abstract interface class AiAccessProvider {
  Future<AiAccess> refreshAccess();
}

abstract interface class AiRunMetadata {
  String get lastModel;
  bool get lastWasDemonstration;
}

class AiQuizQuestion {
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  const AiQuizQuestion({
    required this.prompt,
    required this.options,
    required this.answerIndex,
    this.explanation = '',
  });
}

String aiModelLabel(AiService service) => service is AiRunMetadata
    ? (service as AiRunMetadata).lastModel
    : service.configured
    ? 'Modelo no informado'
    : 'Sin modelo · demostración local';
bool aiWasDemo(AiService service) => service is AiRunMetadata
    ? (service as AiRunMetadata).lastWasDemonstration
    : !service.configured;

abstract interface class AiService {
  void cancel();
  bool get configured;
  Future<String> transform(String text, AiAction action);
  Future<List<AiQuizQuestion>> generateQuiz(String text);
  Future<AnalysisProposal> analyze(List<PickedFile> files, Library library);
}

abstract interface class IdentityService {
  bool get configured;
  String? get displayName;
  Future<void> signIn();
  Future<void> signOut();
  Future<String?> idToken();
}

abstract interface class AccountIdentityService {
  String? get userId;
}

abstract interface class ProfilePhotoIdentityService {
  String? get photoUrl;
}

/// Switches between separately encrypted local libraries owned by each profile.
abstract interface class ProfileVaultService {
  String get activeOwnerId;
  Future<int> guestNoteCount();
  Future<bool> guestMovePromptEnabled();
  Future<void> setGuestMovePromptEnabled(bool enabled);
  Future<void> activate(String ownerId);
  Future<void> moveGuestTo(String ownerId);
}

const guestProfileId = 'guest';

/// AI routing and guest-owned provider configuration.
abstract interface class AiConnection {
  bool get configured;
  bool get isGoogleAccount;
  bool get usesGoogleCloud;
  bool get canDisconnect;
  String get endpoint;
  String get model;
  Future<void> connect(String endpoint, String apiKey, String model);
  Future<void> disconnect();
}

abstract interface class ExampleService {
  Future<int> load();
  Future<int> clear();
}
