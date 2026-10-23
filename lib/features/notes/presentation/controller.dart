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
final profileVaultPort = Provider<ProfileVaultService>(
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
  final bool entered, pro;
  final String theme, locale, profileName, profileImage, paperStyle, fontFamily;
  final int used;
  const Settings({
    this.entered = false,
    this.pro = false,
    this.theme = 'dark',
    this.locale = 'es',
    this.profileName = '',
    this.profileImage = '',
    this.paperStyle = 'plain',
    this.fontFamily = 'Inter',
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
    pro: await ref.read(policyPort).pro,
    theme: await _repo.preference('theme') ?? 'dark',
    locale: await _repo.preference('locale') ?? 'es',
    profileName: await _repo.preference('profile_name') ?? '',
    profileImage: await _repo.preference('profile_image') ?? '',
    paperStyle: _validPaperStyle(await _repo.preference('paper_style')),
    fontFamily: _validFont(await _repo.preference('font_family')),
    used: await ref.read(policyPort).used(),
  );

  String _validPaperStyle(String? value) =>
      const {'plain', 'lines', 'grid', 'dots', 'spaced'}.contains(value)
      ? value!
      : 'plain';
  String _validFont(String? value) =>
      const {'Inter', 'serif', 'monospace'}.contains(value) ? value! : 'Inter';
  Future<void> refresh() async {
    state = AsyncData(await build());
  }

  Future<void> enterGuest() async {
    await ref.read(identityPort).signOut();
    await ref.read(profileVaultPort).activate(guestProfileId);
    await _repo.setPreference('entered', 'true');
    ref.invalidate(libraryProvider);
    await refresh();
  }

  Future<void> enterGoogle({required bool moveGuestNotes}) async {
    final identity = ref.read(identityPort);
    if (identity is! AccountIdentityService) {
      throw const AppFailure('Google no devolvió una cuenta válida.');
    }
    final userId = (identity as AccountIdentityService).userId;
    if (userId == null) {
      throw const AppFailure('Google no devolvió una cuenta válida.');
    }
    final profiles = ref.read(profileVaultPort);
    if (profiles.activeOwnerId == guestProfileId && moveGuestNotes) {
      await profiles.moveGuestTo(userId);
    }
    await profiles.activate(userId);
    await _repo.setPreference('entered', 'true');
    ref.invalidate(libraryProvider);
    ref.invalidate(aiAccessProvider);
    await refresh();
  }

  Future<void> leave() async {
    await _repo.setPreference('entered', 'false');
    await ref.read(identityPort).signOut();
    await ref.read(profileVaultPort).activate(guestProfileId);
    await _repo.setPreference('entered', 'false');
    ref.invalidate(libraryProvider);
    ref.invalidate(aiAccessProvider);
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

  Future<void> saveProfile({
    required String name,
    required String image,
  }) async {
    await _repo.setPreference('profile_name', name.trim());
    await _repo.setPreference('profile_image', image);
    await refresh();
  }

  Future<void> paperStyle(String value) async {
    await _repo.setPreference('paper_style', _validPaperStyle(value));
    await refresh();
  }

  Future<void> fontFamily(String value) async {
    await _repo.setPreference('font_family', _validFont(value));
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
    if (access.limit > 0 && state.value?.pro != access.pro) {
      await plan(access.pro);
    }
    return access;
  }

  Future<void> _checkAccess(AiAccess? access, {bool sources = false}) async {
    if (access == null) {
      await ref.read(policyPort).check(ocr: sources);
      return;
    }
    if (sources && !access.vision) {
      throw const AppFailure(
        'El servidor de IA no tiene habilitado el análisis de imágenes.',
      );
    }
    if (access.remaining <= 0) {
      throw const AppFailure(
        'Alcanzaste el límite diario de IA. Vuelve a intentarlo mañana.',
      );
    }
    if (access.globalRemaining == 0) {
      throw const AppFailure(
        'El servicio de IA alcanzó su límite diario. Vuelve a intentarlo mañana.',
      );
    }
  }

  Future<String> transform(String text, AiAction action) async {
    await _checkAccess(await syncAiAccess());
    try {
      final result = await ref.read(aiPort).transform(text, action);
      await ref.read(policyPort).recordSuccess();
      await refresh();
      return result;
    } finally {
      ref.invalidate(aiAccessProvider);
    }
  }

  Future<AnalysisProposal> analyze(List<PickedFile> files, Library lib) async {
    await _checkAccess(await syncAiAccess(), sources: true);
    try {
      final result = await ref.read(aiPort).analyze(files, lib);
      await ref.read(policyPort).recordSuccess();
      await refresh();
      return result;
    } finally {
      ref.invalidate(aiAccessProvider);
    }
  }
}

// Server quota is authoritative for connected devices; local counts are demo-only.
final aiAccessProvider = FutureProvider.autoDispose<AiAccess?>((ref) async {
  final service = ref.watch(aiPort);
  if (!service.configured || service is! AiAccessProvider) return null;
  return (service as AiAccessProvider).refreshAccess();
});
