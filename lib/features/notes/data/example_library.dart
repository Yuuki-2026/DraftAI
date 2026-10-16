import 'dart:convert';
import 'dart:ui' as ui;

import 'package:pdf/widgets.dart' as pw;

import '../domain/entities.dart';
import '../domain/ports.dart';
import '../domain/note_document.dart';

/// Explicit opt-in fixtures. No examples are loaded at app startup.
class ExampleLibrary implements ExampleService {
  final NotesRepository notes;
  final MediaRepository media;
  final String Function() newId;
  ExampleLibrary(this.notes, this.media, this.newId);
  @override
  Future<int> load() async {
    final lib = await notes.load();
    if (lib.notes.any((n) => n.id.startsWith('demo_'))) {
      throw const AppFailure('Los ejemplos ya están cargados.');
    }
    final prefix = 'demo_${newId()}';
    final topics = [
      (
        'Facultad de Ingeniería',
        'Cálculo Diferencial',
        'La derivada describe la variación instantánea de una función. En geometría corresponde a la pendiente de su recta tangente. Se estudian límites, continuidad, regla de la cadena y optimización. Para f(x)=x² se obtiene f′(x)=2x; en x=3 la pendiente es 6. Se comprueban dominio, unidades e interpretación antes de concluir.',
      ),
      (
        'Proyectos Personales',
        'Diseño de una aplicación',
        'Un proyecto comienza con una necesidad concreta. Se definen las personas que usarán el producto, sus tareas principales y los criterios de aceptación. Un prototipo permite revisar navegación y comprensión antes de implementar. Las decisiones se registran para facilitar el mantenimiento.',
      ),
      (
        'Lecturas',
        'Comprensión y síntesis',
        'Resumir consiste en identificar las ideas centrales y sus relaciones. Primero se reconoce el tema y luego se diferencian argumentos, ejemplos y conclusiones. Una síntesis conserva el significado del material original y señala las dudas que requieren revisar la fuente.',
      ),
      (
        'Vida diaria',
        'Planificación semanal',
        'Una planificación realista distingue compromisos, tareas y descansos. Las tareas se ordenan por importancia y urgencia. Se reserva tiempo para imprevistos y se revisa el avance al finalizar la semana. Una tarea grande puede dividirse en pasos pequeños y verificables.',
      ),
    ];
    topics.addAll([
      (
        'Matemáticas avanzadas',
        'Teorema de Stokes',
        'El teorema de Stokes relaciona la integral de línea sobre una curva cerrada con la integral del rotacional sobre una superficie orientada. La regla de la mano derecha determina la orientación. Se exige un campo con derivadas continuas y se revisan las condiciones de frontera. La expresión es ∮ F · dr = ∬ (∇ × F) · n dS.',
      ),
      (
        'Física',
        'Movimiento parabólico',
        'La velocidad horizontal permanece constante cuando se ignora el rozamiento. La componente vertical cambia por la gravedad. Las ecuaciones x=v₀ cos(θ)t e y=v₀ sen(θ)t−gt²/2 permiten calcular posición y tiempo de vuelo. Se separan los ejes y se comprueban las unidades de cada término.',
      ),
      (
        'Química',
        'Química Orgánica',
        'Los alcanos presentan enlaces sencillos; los alquenos y alquinos incluyen enlaces múltiples. Para nombrar una molécula se identifica la cadena principal, se numeran sustituyentes y se reconocen grupos funcionales. La fórmula general CₙH₂ₙ₊₂ corresponde a alcanos acíclicos saturados.',
      ),
      (
        'Investigación',
        'Fuentes y evidencia',
        'Una pregunta de investigación precisa permite decidir qué evidencia es relevante. Se distinguen observaciones, hipótesis y conclusiones. Cada afirmación debe poder rastrearse a una fuente y las limitaciones del método deben describirse. La revisión considera validez, sesgos y posibilidades de reproducir los resultados.',
      ),
    ]);
    final subjects = [
      ['Cálculo Diferencial', 'Física General', 'Álgebra Lineal'],
      ['Ideas de Aplicaciones', 'Lecturas Pendientes', 'Plan de proyecto'],
      ['Comprensión lectora', 'Síntesis de argumentos', 'Lectura crítica'],
      ['Planificación semanal', 'Hábitos y objetivos', 'Organización personal'],
      ['Teorema de Stokes', 'Integrales de superficie', 'Campos vectoriales'],
      ['Movimiento parabólico', 'Energía y movimiento', 'Leyes de Newton'],
      ['Química Orgánica', 'Hidrocarburos', 'Grupos funcionales'],
      [
        'Fuentes y evidencia',
        'Diseño de investigación',
        'Análisis de resultados',
      ],
    ];
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFF7F8FA), ui.BlendMode.src);
    final pen = ui.Paint()
      ..color = const ui.Color(0xFF246579)
      ..strokeWidth = 4
      ..style = ui.PaintingStyle.stroke;
    canvas.drawLine(const ui.Offset(35, 190), const ui.Offset(390, 190), pen);
    canvas.drawLine(const ui.Offset(35, 190), const ui.Offset(35, 20), pen);
    final curve = ui.Path()
      ..moveTo(35, 180)
      ..cubicTo(100, 165, 220, 25, 385, 35);
    canvas.drawPath(curve, pen);
    final picture = recorder.endRecording();
    final image = await picture.toImage(420, 220);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
    final diagrams = [png];
    for (var variant = 0; variant < 2; variant++) {
      final record = ui.PictureRecorder();
      final c = ui.Canvas(record);
      c.drawColor(const ui.Color(0xFFF7F8FA), ui.BlendMode.src);
      final p = ui.Paint()
        ..color = const ui.Color(0xFF496C8B)
        ..strokeWidth = 4
        ..style = ui.PaintingStyle.stroke;
      c.drawLine(const ui.Offset(35, 190), const ui.Offset(390, 190), p);
      c.drawLine(const ui.Offset(35, 190), const ui.Offset(35, 20), p);
      if (variant == 0) {
        c.drawPath(
          ui.Path()
            ..moveTo(35, 170)
            ..lineTo(110, 85)
            ..lineTo(185, 155)
            ..lineTo(260, 50)
            ..lineTo(385, 110),
          p,
        );
      } else {
        p.style = ui.PaintingStyle.fill;
        for (var bar = 0; bar < 5; bar++) {
          c.drawRect(
            ui.Rect.fromLTWH(
              55 + bar * 65,
              150.0 - bar * 24,
              35,
              40.0 + bar * 24,
            ),
            p,
          );
        }
      }
      final picture = record.endRecording();
      final image = await picture.toImage(420, 220);
      diagrams.add(
        (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
      image.dispose();
      picture.dispose();
    }
    final pdf = pw.Document()
      ..addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DraftAI - Documento de ejemplo',
                style: pw.TextStyle(fontSize: 22),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Material ficticio para probar el visor PDF, la organizacion y la exportacion de notas.',
              ),
              pw.SizedBox(height: 20),
              pw.Image(pw.MemoryImage(png)),
            ],
          ),
        ),
      );
    final pdfBytes = await pdf.save();
    var count = 0;
    for (var group = 0; group < topics.length; group++) {
      final (folderName, _, body) = topics[group];
      final folder = Folder(
        '${prefix}_folder$group',
        folderName,
        [
          0xFFFFFFFF,
          0xFF9E9E9E,
          0xFFA5C5E5,
          0xFFB7D7B0,
          0xFFC5AFE0,
          0xFFE5CCA5,
          0xFFE1BAC5,
          0xFFC0D2D6,
        ][group],
      );
      await notes.saveFolder(folder);
      for (var i = 0; i < 15; i++) {
        final now = DateTime.now().toUtc().subtract(
          Duration(days: (group * 15 + i) * 2),
        );
        final attachments = <Attachment>[];
        if (i % 5 == 0) {
          for (var figure = 0; figure < diagrams.length; figure++) {
            attachments.add(
              await media.store(
                PickedFile('figura$figure.png', 'image/png', diagrams[figure]),
              ),
            );
          }
        }
        if (i % 5 == 1) {
          attachments.add(
            await media.store(
              PickedFile('guia.pdf', 'application/pdf', pdfBytes),
            ),
          );
        }
        final subject = subjects[group][i % 3];
        final session = i + 1;
        final development =
            '$body\n\nSesión $session: se plantea un caso de aplicación, se identifican las variables y se ordenan las etapas de resolución. La primera revisión separa los datos conocidos de las suposiciones. Se explica el procedimiento con palabras antes de aplicarlo y se contrasta el resultado con una estimación.\n\nEjemplo de análisis: un registro contiene ${12 + i} observaciones, agrupadas en ${3 + group} conjuntos. Cada conjunto se revisa por separado y luego se comparan sus resultados. Se documentan las condiciones iniciales y se indica qué conclusiones dependen de ellas.\n\nPara preparar el resumen se reconoce la idea principal, se conservan las definiciones y se distinguen los ejemplos. Una explicación clara enlaza las premisas con sus consecuencias y evita introducir información sin sustento.';
        final doc = <Map<String, dynamic>>[
          ...NoteDocument.formatted('# $subject\n$body'),
          if (attachments.isNotEmpty) ...[
            for (final attachment in attachments) ...[
              {
                'insert': {NoteDocument.mediaKey: attachment.id},
              },
              {'insert': '\n'},
              ...NoteDocument.formatted(
                '### Observación de la figura\nLa representación permite comparar la tendencia, los valores y su interpretación dentro del apunte.\n',
              ),
            ],
          ],
          ...NoteDocument.formatted(
            '## Ideas principales\n- Reconocer los conceptos y sus relaciones.\n- Distinguir datos, ejemplos y conclusiones.\n- Revisar las fuentes antes de tomar decisiones.\n## Desarrollo\n$development\n## Preguntas de repaso\n¿Cuál es la idea principal? ¿Qué ejemplos la explican? ¿Qué información falta verificar?',
          ),
        ];
        await notes.save(
          Note(
            id: '${prefix}_note${count++}',
            folderId: folder.id,
            title: '$subject · Sesión $session',
            topic: subject,
            plainText: '$subject\n$body\nIdeas principales\n$development',
            document: jsonEncode(doc),
            attachments: attachments,
            createdAt: now,
            updatedAt: now,
          ),
          reason: 'Ejemplo opcional',
        );
      }
    }
    return count;
  }

  @override
  Future<int> clear() async {
    final lib = await notes.load();
    final samples = lib.notes.where((n) => n.id.startsWith('demo_')).toList();
    final candidates = <String, Attachment>{};
    for (final n in samples) {
      for (final a in n.attachments) {
        candidates[a.id] = a;
      }
      for (final r in await notes.history(n.id)) {
        for (final a in r.note.attachments) {
          candidates[a.id] = a;
        }
      }
      await notes.deletePermanently(n.id);
    }
    final remaining = await notes.load();
    final used = <String>{};
    for (final n in remaining.notes) {
      used.addAll(n.attachments.map((a) => a.id));
      for (final r in await notes.history(n.id)) {
        used.addAll(r.note.attachments.map((a) => a.id));
      }
    }
    for (final a in candidates.values.where((a) => !used.contains(a.id))) {
      await media.delete(a);
    }
    for (final f in lib.folders.where(
      (f) =>
          f.id.startsWith('demo_') &&
          !remaining.notes.any((n) => n.folderId == f.id),
    )) {
      await notes.deleteFolder(f.id);
    }
    return samples.length;
  }
}
