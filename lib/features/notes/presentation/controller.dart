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
final idPort = Provider<String Function()>((ref) => throw UnimplementedError());
final libraryProvider = StreamProvider<Library>(
  (ref) => ref.watch(notesPort).watch(),
);

class Settings {
  final bool entered;
  final String theme, locale, profileName, profileImage, paperStyle, fontFamily;

  const Settings({
    this.entered = false,

    this.theme = 'dark',
    this.locale = 'es',
    this.profileName = '',
    this.profileImage = '',
    this.paperStyle = 'plain',
    this.fontFamily = 'Inter',
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

    theme: await _repo.preference('theme') ?? 'dark',
    locale: await _repo.preference('locale') ?? 'es',
    profileName: await _repo.preference('profile_name') ?? '',
    profileImage: await _repo.preference('profile_image') ?? '',
    paperStyle: _validPaperStyle(await _repo.preference('paper_style')),
    fontFamily: _validFont(await _repo.preference('font_family')),
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

  bool _changingProfile = false;

  Future<void> _changeProfile(Future<void> Function() change) async {
    if (_changingProfile) {
      throw const AppFailure('Espera a que termine el cambio de perfil.');
    }
    final service = ref.read(aiPort);
    final connection = service is AiConnection ? service as AiConnection : null;
    _changingProfile = true;
    try {
      try {
        await connection?.endProfileSession();
        await change();
      } finally {
        await connection?.loadProfile();
      }
      ref.invalidate(libraryProvider);
      await refresh();
    } finally {
      _changingProfile = false;
    }
  }

  Future<void> enterGuest() => _changeProfile(() async {
    await ref.read(identityPort).signOut();
    await ref.read(profileVaultPort).activate(guestProfileId);
    await _repo.setPreference('entered', 'true');
  });

  Future<void> enterGoogle({required bool moveGuestNotes}) =>
      _changeProfile(() async {
        final identity = ref.read(identityPort);
        final userId = identity is AccountIdentityService
            ? (identity as AccountIdentityService).userId
            : null;
        if (userId == null) {
          throw const AppFailure('Google no devolvió una cuenta válida.');
        }
        final profiles = ref.read(profileVaultPort);
        if (profiles.activeOwnerId == guestProfileId && moveGuestNotes) {
          await profiles.moveGuestTo(userId);
        }
        await profiles.activate(userId);
        await _repo.setPreference('entered', 'true');
      });

  Future<void> leave() => _changeProfile(() async {
    await _repo.setPreference('entered', 'false');
    await ref.read(identityPort).signOut();
    await ref.read(profileVaultPort).activate(guestProfileId);
    await _repo.setPreference('entered', 'false');
  });

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

  Future<String> transform(String text, AiAction action) =>
      ref.read(aiPort).transform(text, action);

  Future<AnalysisProposal> analyze(List<PickedFile> files, Library lib) =>
      ref.read(aiPort).analyze(files, lib);
}
