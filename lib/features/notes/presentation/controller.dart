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
  final bool entered, pro;
  final String theme, locale;
  final int used;
  const Settings({
    this.entered = false,
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
    pro: await ref.read(policyPort).pro,
    theme: await _repo.preference('theme') ?? 'dark',
    locale: await _repo.preference('locale') ?? 'es',
    used: await ref.read(policyPort).used(),
  );
  Future<void> refresh() async {
    state = AsyncData(await build());
  }

  Future<void> enter({bool google = false}) async {
    if (google) await ref.read(identityPort).signIn();
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
    final lib = await _repo.load();
    if (lib.notes.isNotEmpty) {
      throw const AppFailure(
        'Los ejemplos solo se cargan en una biblioteca vacía.',
      );
    }
    final folder1 = Folder(newId(), 'Facultad de Ingeniería', 0xFFFFFFFF);
    final folder2 = Folder(newId(), 'Proyectos Personales', 0xFF9E9E9E);
    await folder(folder1);
    await folder(folder2);
    final examples = [
      (
        'Cálculo Vectorial: Teorema de Stokes',
        'Geometría diferencial',
        'El teorema de Stokes establece una relación fundamental entre la integral de línea de un campo vectorial y la integral de superficie del rotacional sobre una superficie orientada.\n\nFormulación integral general\n∮ F · dr = ∬ (∇ × F) · n dS\n\nLa orientación positiva queda determinada por la regla de la mano derecha.\n\nNotas y condiciones de frontera\n• El campo debe tener derivadas parciales continuas.\n• La curva cerrada define el contorno de la superficie.',
      ),
      (
        'Física General: Movimiento parabólico',
        'Cinemática',
        'La pendiente de una gráfica de posición representa la velocidad. En un movimiento parabólico, la componente horizontal de la velocidad permanece constante y la vertical cambia por efecto de la gravedad.\n\nx = v₀ cos(θ) t\ny = v₀ sen(θ) t − ½ g t²',
      ),
      (
        'Química Orgánica: Hidrocarburos',
        'Química',
        'Los alcanos presentan enlaces sencillos; alquenos y alquinos incorporan enlaces múltiples.\n\nSerie de alcanos: CₙH₂ₙ₊₂\n\nLa longitud y las ramificaciones determinan el nombre base.',
      ),
      (
        'Álgebra Lineal: Transformaciones',
        'Espacios vectoriales',
        'Una transformación lineal conserva sumas y multiplicaciones por escalares. Cada columna de su matriz muestra la imagen de un vector unitario.',
      ),
      (
        'Ideas de Aplicaciones',
        'Proyecto',
        'Convertir cada idea prioritaria en una tarea breve y enlazarla con sus referencias.',
      ),
      (
        'Lecturas Pendientes',
        'Investigación',
        'Necesidades y contexto\nArquitectura de información\nPrototipos y pruebas',
      ),
    ];
    for (var i = 0; i < examples.length; i++) {
      final e = examples[i];
      final now = DateTime.now().toUtc().subtract(Duration(minutes: i));
      await save(
        Note(
          id: newId(),
          folderId: i < 4 ? folder1.id : folder2.id,
          title: e.$1,
          topic: e.$2,
          plainText: e.$3,
          createdAt: now,
          updatedAt: now,
        ),
        reason: 'Ejemplo del mockup',
      );
    }
  }

  Future<String> transform(String text, AiAction action) async {
    await ref.read(policyPort).check();
    final result = await ref.read(aiPort).transform(text, action);
    await ref.read(policyPort).recordSuccess();
    await refresh();
    return result;
  }

  Future<AnalysisProposal> analyze(List<PickedFile> files, Library lib) async {
    await ref.read(policyPort).check(ocr: true);
    final result = await ref.read(aiPort).analyze(files, lib);
    await ref.read(policyPort).recordSuccess();
    await refresh();
    return result;
  }
}
