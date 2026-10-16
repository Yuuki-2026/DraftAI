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
        'Ciencias',
        'Energía y movimiento',
        'La energía se conserva en un sistema aislado. La energía cinética depende de la masa y del cuadrado de la velocidad. La energía potencial gravitatoria depende de la altura. Para resolver un problema se identifican las condiciones iniciales, las fuerzas y las unidades.',
      ),
      (
        'Proyectos',
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
      final (folderName, topic, body) = topics[group];
      final folder = Folder(
        '${prefix}_folder$group',
        'Ejemplos · $folderName',
        [0xFFA5C5E5, 0xFFB7D7B0, 0xFFC5AFE0, 0xFFE5CCA5][group],
      );
      await notes.saveFolder(folder);
      final category = Category(
        '${prefix}_category$group',
        folder.id,
        'Material de prueba',
      );
      await notes.saveCategory(category);
      for (var i = 0; i < 5; i++) {
        final now = DateTime.now().toUtc().subtract(
          Duration(days: group * 5 + i),
        );
        final attachments = <Attachment>[];
        if (i == 0) {
          attachments.add(
            await media.store(PickedFile('ejemplo.png', 'image/png', png)),
          );
        }
        if (i == 1) {
          attachments.add(
            await media.store(
              PickedFile('guia.pdf', 'application/pdf', pdfBytes),
            ),
          );
        }
        final doc = <Map<String, dynamic>>[
          ...NoteDocument.formatted('# $topic\n$body'),
          if (attachments.isNotEmpty) ...[
            {
              'insert': {NoteDocument.mediaKey: attachments.first.id},
            },
            {'insert': '\n'},
          ],
          ...NoteDocument.formatted(
            '## Ideas principales\n- Reconocer los conceptos y sus relaciones.\n- Distinguir datos, ejemplos y conclusiones.\n- Revisar las fuentes antes de tomar decisiones.\n## Desarrollo\n$body\n\n$body\n## Preguntas de repaso\n¿Cuál es la idea principal? ¿Qué ejemplos la explican? ¿Qué información falta verificar?',
          ),
        ];
        await notes.save(
          Note(
            id: '${prefix}_note${count++}',
            folderId: folder.id,
            categoryId: category.id,
            title: '$topic · ${i + 1}',
            topic: topic,
            plainText: '$topic\n$body\nIdeas principales\n$body\n$body',
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
