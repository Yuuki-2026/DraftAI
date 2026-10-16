import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import '../domain/ports.dart';
import '../domain/use_cases.dart';

final examplesPort = Provider<ExampleService>(
  (ref) => throw UnimplementedError(),
);

final notesPort = Provider<NotesRepository>(
  (ref) => throw UnimplementedError(),
);
final mediaPort = Provider<MediaRepository>(
  (ref) => throw UnimplementedError(),
);
final exportPort = Provider<ExportService>((ref) => throw UnimplementedError());
final aiPort = Provider<AiService>((ref) => throw UnimplementedError());
final identityPort = Provider<IdentityService>(
  (ref) => throw UnimplementedError(),
);
final speechPort = Provider<SpeechService>((ref) => throw UnimplementedError());
final actionsPort = Provider<NoteActions>((ref) => throw UnimplementedError());
final policyPort = Provider<AiPolicy>((ref) => throw UnimplementedError());
final idPort = Provider<String Function()>((ref) => throw UnimplementedError());
final libraryProvider = StreamProvider<Library>(
  (ref) => ref.watch(notesPort).watch(),
);

class Settings {
  final bool entered, pro, testUser;
  final String theme, locale;
  final int used;
  const Settings({
    this.entered = false,
    this.testUser = false,
    this.pro = false,
    this.theme = 'dark',
    this.locale = 'es',
    this.used = 0,
  });
}

final controllerProvider = AsyncNotifierProvider<AppController, Settings>(
  AppController.new,
);

class AppController extends AsyncNotifier<Settings> {
  NotesRepository get _repo => ref.read(notesPort);
  NoteActions get _actions => ref.read(actionsPort);
  @override
  Future<Settings> build() async => Settings(
    entered: await _repo.preference('entered') == 'true',
    testUser: await _repo.preference('beta_user') == 'true',
    pro: await ref.read(policyPort).pro,
    theme: await _repo.preference('theme') ?? 'dark',
    locale: await _repo.preference('locale') ?? 'es',
    used: await ref.read(policyPort).used(),
  );
  Future<void> refresh() async {
    state = AsyncData(await build());
  }

  Future<void> enter({bool google = false, bool testUser = false}) async {
    if (google) await ref.read(identityPort).signIn();
    await _repo.setPreference('beta_user', testUser ? 'true' : 'false');
    await _repo.setPreference('entered', 'true');
    await refresh();
  }

  Future<void> leave() async {
    await ref.read(identityPort).signOut();
    await _repo.setPreference('entered', 'false');
    await refresh();
  }

  Future<void> plan(bool pro) async {
    await _repo.setPreference('plan', pro ? 'pro_demo' : 'free');
    await refresh();
  }

  Future<void> theme(String v) async {
    await _repo.setPreference('theme', v);
    await refresh();
  }

  Future<void> locale(String v) async {
    await _repo.setPreference('locale', v);
    await refresh();
  }

  Future<Note> create(
    String folderId, {
    String title = 'Sin título',
    String? categoryId,
  }) => _actions.create(folderId, title: title, categoryId: categoryId);
  Future<void> save(Note n, {String reason = 'Edición'}) =>
      _actions.save(n, reason: reason);
  Future<void> trash(Note n) => _actions.trash(n);
  Future<void> restore(Note n) => _actions.restore(n);
  Future<void> remove(Note n) async {
    final revisions = await _repo.history(n.id);
    final attachments = <String, Attachment>{
      for (final a in n.attachments) a.id: a,
      for (final revision in revisions)
        for (final a in revision.note.attachments) a.id: a,
    };
    await _repo.deletePermanently(n.id);
    final remaining = await _repo.load();
    final referenced = <String>{};
    for (final other in remaining.notes) {
      referenced.addAll(other.attachments.map((a) => a.id));
      for (final revision in await _repo.history(other.id)) {
        referenced.addAll(revision.note.attachments.map((a) => a.id));
      }
    }
    for (final a in attachments.values.where(
      (a) => !referenced.contains(a.id),
    )) {
      await ref.read(mediaPort).delete(a);
    }
  }

  Future<List<Revision>> history(String id) => _repo.history(id);
  Future<void> folder(Folder f) => _repo.saveFolder(f);
  Future<void> category(Category c) => _repo.saveCategory(c);
  Future<void> deleteFolder(String id) => _repo.deleteFolder(id);
  String newId() => ref.read(idPort)();
  Future<void> loadExamples() async {
    await ref.read(examplesPort).load();
  }

  Future<AiAccess?> syncAiAccess() async {
    final service = ref.read(aiPort);
    if (service is! AiAccessProvider) return null;
    final access = await (service as AiAccessProvider).refreshAccess();
    if (state.value?.pro != access.pro) await plan(access.pro);
    return access;
  }

  Future<String> transform(String text, AiAction action) async {
    await syncAiAccess();
    await ref.read(policyPort).check();
    final result = await ref.read(aiPort).transform(text, action);
    await ref.read(policyPort).recordSuccess();
    await refresh();
    return result;
  }

  Future<AnalysisProposal> analyze(List<PickedFile> files, Library lib) async {
    final access = await syncAiAccess();
    if (access != null && !access.vision) {
      throw const AppFailure(
        'Conectado como Gratis. Usa el código Pro de prueba para analizar imágenes o documentos.',
      );
    }
    await ref.read(policyPort).check(ocr: true);
    final result = await ref.read(aiPort).analyze(files, lib);
    await ref.read(policyPort).recordSuccess();
    await refresh();
    return result;
  }
}
