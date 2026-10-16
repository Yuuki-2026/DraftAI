import 'dart:convert';

import 'source_draft.dart';
export 'source_draft.dart';
import 'destination_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import '../../notes/domain/note_document.dart';
import '../../notes/presentation/controller.dart';
import '../../notes/presentation/note_page.dart';
import '../../notes/presentation/rich_ai_text.dart';

List<List<PickedFile>> sourceGroups(List<PickedFile> files) {
  final groups = <List<PickedFile>>[];
  var group = <PickedFile>[], size = 0;
  for (final file in files) {
    if (file.bytes.length > 8 * 1024 * 1024) {
      throw const AppFailure('Cada fuente para IA debe pesar hasta 8 MB.');
    }
    if (group.length == 5 || size + file.bytes.length > 10 * 1024 * 1024) {
      groups.add(group);
      group = [];
      size = 0;
    }
    group.add(file);
    size += file.bytes.length;
  }
  if (group.isNotEmpty) groups.add(group);
  return groups;
}

class SourceAnalysisPage extends ConsumerStatefulWidget {
  final List<List<PickedFile>> groups;
  final Library library;
  const SourceAnalysisPage({
    super.key,
    required this.groups,
    required this.library,
  });
  @override
  ConsumerState<SourceAnalysisPage> createState() => _AnalysisState();
}

class _AnalysisState extends ConsumerState<SourceAnalysisPage> {
  bool running = true, cancelled = false, leaving = false;
  int group = 0;
  String? error;
  final results = <SourceDraft>[];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final starts = <DateTime>[];
    try {
      for (var i = 0; i < widget.groups.length; i++) {
        if (cancelled || !mounted) return;
        setState(() => group = i);
        starts.removeWhere((t) => DateTime.now().difference(t).inSeconds >= 61);
        while (starts.length >= 4 &&
            DateTime.now().difference(starts.first).inSeconds < 61) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (cancelled || !mounted) return;
        }
        if (starts.length >= 4) starts.removeAt(0);
        starts.add(DateTime.now());
        final files = widget.groups[i];
        final result = await ref
            .read(controllerProvider.notifier)
            .analyze(files, widget.library);
        if (cancelled || !mounted) return;
        final items = result.items.isEmpty ? [result] : result.items;
        if (items.length != files.length) {
          throw const AppFailure('Falta un resultado por fuente.');
        }
        for (var n = 0; n < items.length; n++) {
          results.add(SourceDraft(files[n], items[n], widget.library));
        }
        setState(() {});
      }
      if (mounted && !cancelled) {
        setState(() {
          running = false;
          leaving = true;
        });
        Navigator.pop(context, results);
      }
    } catch (e) {
      if (mounted && !cancelled) {
        setState(() {
          error = '$e';
          running = false;
        });
      }
    }
  }

  void _cancel() {
    cancelled = true;
    ref.read(aiPort).cancel();
    setState(() {
      leaving = true;
      running = false;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.groups[group];
    final total = widget.groups.fold<int>(0, (sum, g) => sum + g.length);
    return PopScope(
      canPop: leaving || !running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Déjalo a la IA · Analizando'))),
        body: SafeArea(
          child: ResponsiveBody(
            maxWidth: 720,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: error == null ? results.length / total : null,
                ),
                const SizedBox(height: 12),
                Meta(
                  '${tr(context, 'PASO 1 DE 2 · ANALIZANDO')} · ${group + 1}/${widget.groups.length}',
                ),
                const SizedBox(height: 16),
                Surface(
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        files.first.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, '${files.length} fuentes en este grupo'),
                      ),
                      const SizedBox(height: 8),
                      Meta(
                        tr(
                          context,
                          'Leyendo contenido y buscando destinos por nombre',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                if (running)
                  const Center(
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  tr(
                    context,
                    error == null
                        ? 'Analizando y organizando…'
                        : 'No se completó el análisis',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  error ??
                      tr(
                        context,
                        'La IA lee las fuentes, prepara un resumen interno y sugiere carpeta y apunte.',
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                for (final label in [
                  'Extrayendo texto y fórmulas',
                  'Identificando contenido académico',
                  'Sugiriendo carpeta y apunte',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Surface(
                      radius: 16,
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_empty, size: 18),
                          const SizedBox(width: 12),
                          Expanded(child: Text(tr(context, label))),
                          Meta(tr(context, running ? 'En curso' : 'Detenido')),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Meta(
                  tr(
                    context,
                    'Solo se muestran resultados cuando el proveedor responde. No se guarda nada sin tu revisión.',
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close),
                  label: Text(
                    tr(
                      context,
                      running ? 'Cancelar proceso' : 'Volver al lote',
                    ),
                  ),
                ),
                if (!running && results.isNotEmpty)
                  FilledButton(
                    onPressed: () {
                      setState(() => leaving = true);
                      Navigator.pop(context, results);
                    },
                    child: Text(tr(context, 'Revisar las fuentes analizadas')),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SourceReviewPage extends ConsumerStatefulWidget {
  final List<SourceDraft> drafts;
  final bool manual;
  const SourceReviewPage({
    super.key,
    required this.drafts,
    this.manual = false,
  });
  @override
  ConsumerState<SourceReviewPage> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<SourceReviewPage> {
  bool busy = false;
  int index = 0;
  final folderCache = <String, String>{};
  final noteCache = <String, Note>{};
  String _folder(SourceDraft d, Library lib) =>
      lib.folders.where((f) => f.id == d.folderId).firstOrNull?.name ??
      d.folderName;
  String _note(SourceDraft d, Library lib) =>
      lib.active.where((n) => n.id == d.noteId).firstOrNull?.title ??
      d.noteTitle;
  Future<void> _edit(SourceDraft d) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DestinationPicker(
          drafts: [d],
          reviewOnly: true,
          onComplete: (values) async {
            d.apply(values.single);
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (busy) return;
    final chosen = widget.drafts.where((d) => d.include && !d.saved).toList();
    if (chosen.isEmpty) {
      message(context, tr(context, 'Selecciona al menos una fuente.'));
      return;
    }
    setState(() => busy = true);
    Note? last;
    await runAction(context, () async {
      final ctrl = ref.read(controllerProvider.notifier);
      for (final d in chosen) {
        final lib =
            ref.read(libraryProvider).value ?? const Library([], [], []);
        var folderId = d.folderId;
        if (folderId == null) {
          final name = d.folderName.trim().isEmpty
              ? 'Mis apuntes'
              : d.folderName.trim();
          folderId =
              lib.folders
                  .where((f) => f.name.toLowerCase() == name.toLowerCase())
                  .firstOrNull
                  ?.id ??
              folderCache[name.toLowerCase()];
          if (folderId == null) {
            final f = Folder(ctrl.newId(), name, 0xFFFFFFFF);
            await ctrl.folder(f);
            folderId = f.id;
            folderCache[name.toLowerCase()] = f.id;
          }
        }
        final targetTitle = d.noteTitle.trim().isEmpty
            ? 'Nuevo apunte'
            : d.noteTitle.trim();
        final key = d.noteId ?? '$folderId:${targetTitle.toLowerCase()}';
        var note =
            noteCache[key] ??
            lib.active
                .where(
                  (n) => d.noteId != null
                      ? n.id == d.noteId
                      : n.folderId == folderId &&
                            n.title.toLowerCase() == targetTitle.toLowerCase(),
                )
                .firstOrNull;
        note ??= Note(
          id: ctrl.newId(),
          folderId: folderId,
          title: targetTitle,
          topic: d.proposal?.topic ?? '',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        final added = <Attachment>[];
        try {
          if (!d.file.mime.startsWith('text/')) {
            added.add(await ref.read(mediaPort).store(d.file));
          }
          final ops = <Map<String, dynamic>>[
            ...NoteDocument.delta(note),
            if (d.text.trim().isNotEmpty)
              ...NoteDocument.formatted(
                '${note.plainText.isEmpty ? '' : '## ${d.proposal?.title ?? targetTitle}\n'}${d.text}',
              ),
            for (final a in added) ...[
              {
                'insert': {NoteDocument.mediaKey: a.id},
              },
              {'insert': '\n'},
            ],
          ];
          final summary = d.summary.trim().isEmpty
              ? note.summary
              : [
                  if (note.summary.isNotEmpty) note.summary,
                  d.summary.trim(),
                ].join('\n\n');
          final models = {
            if (note.summaryModel.isNotEmpty) note.summaryModel,
            if (d.model.isNotEmpty) d.model,
          }.join(' · ');
          final updated = note.copyWith(
            document: jsonEncode(ops),
            documentVersion: 2,
            plainText: q.Document.fromJson(ops)
                .toPlainText()
                .replaceAll('\uFFFC', '')
                .trimRight(),
            summary: summary,
            summaryModel: models,
            attachments: [...note.attachments, ...added],
            updatedAt: DateTime.now().toUtc(),
          );
          await ctrl.save(
            updated,
            reason: d.proposal == null
                ? 'Importación manual'
                : 'Fuentes revisadas · ${d.model}',
          );
          noteCache[key] = updated;
          noteCache[updated.id] = updated;
          noteCache['$folderId:${updated.title.toLowerCase()}'] = updated;
          last = updated;
          d.saved = true;
        } catch (_) {
          for (final a in added) {
            await ref.read(mediaPort).delete(a);
          }
          rethrow;
        }
      }
      if (last != null) {
        final savedId = last!.id;
        last =
            (await ref.read(notesPort).load()).active
                .where((n) => n.id == savedId)
                .firstOrNull ??
            last;
      }
      if (mounted && last != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => NotePage(note: last!)),
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Widget _card(SourceDraft d, Library lib) => Surface(
    radius: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 66,
              height: 70,
              child: d.file.mime.startsWith('image/')
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        d.file.bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                      ),
                    )
                  : Icon(
                      d.file.mime == 'application/pdf'
                          ? Icons.picture_as_pdf_outlined
                          : Icons.text_snippet_outlined,
                      size: 36,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Meta(
                    tr(
                      context,
                      widget.manual ? 'DESTINO MANUAL' : 'DESTINO SUGERIDO',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _folder(d, lib),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(_note(d, lib), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Checkbox(
              value: d.include,
              onChanged: busy || d.saved
                  ? null
                  : (v) => setState(() => d.include = v ?? false),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (d.proposal != null) ...[
          Text(
            tr(
              context,
              d.proposal!.academic
                  ? 'Contenido académico'
                  : 'No parece material académico · revisión manual',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!d.proposal!.readable)
            Text(
              tr(
                context,
                'No se pudo leer con claridad. Puedes adjuntarlo manualmente.',
              ),
            ),
          if (d.proposal!.partial)
            Text(
              tr(
                context,
                'Extracción parcial: revisa el original antes de guardar.',
              ),
            ),
          if (d.proposal!.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                d.proposal!.reason,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Meta('${tr(context, 'Analizado por IA')} · ${d.model}'),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                d.file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: busy || d.saved ? null : () => _edit(d),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(tr(context, 'Editar')),
            ),
          ],
        ),
        if (d.text.isNotEmpty || d.summary.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              tr(context, 'Texto y resumen'),
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              if (d.text.isNotEmpty) RichAiText(d.text),
              if (d.summary.isNotEmpty) ...[
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(context, 'Resumen interno'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                RichAiText(d.summary),
              ],
            ],
          ),
        if (d.saved)
          Text(
            tr(context, 'Guardado'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (widget.manual)
      return DestinationPicker(
        drafts: widget.drafts,
        onComplete: (values) async {
          for (var i = 0; i < values.length; i++) {
            widget.drafts[i].apply(values[i]);
          }
          await _save();
        },
      );
    final lib = ref.watch(libraryProvider).value ?? const Library([], [], []);
    final list = widget.manual ? [widget.drafts[index]] : widget.drafts;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                tr(context, busy ? 'Guardando…' : 'Continuar y organizar lote'),
              ),
            ),
          ),
        ),
        appBar: AppBar(
          title: Text(
            tr(
              context,
              widget.manual ? 'Hazlo tú · Categorizar' : 'Análisis de fuentes',
            ),
          ),
        ),
        body: SafeArea(
          child: ResponsiveBody(
            maxWidth: 760,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Meta(
                        tr(context, 'PASO 2 / 2 · REVISIÓN Y CONFIRMACIÓN'),
                      ),
                    ),
                    Pill(
                      tr(
                        context,
                        widget.manual ? 'Manual' : 'Auto-organización',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Surface(
                  radius: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.drafts.length} ${tr(context, widget.manual ? 'fuentes en el lote' : 'fuentes analizadas')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(
                                context,
                                widget.manual
                                    ? 'Elige el destino de cada fuente'
                                    : 'Lectura y análisis de contenido',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  tr(
                    context,
                    widget.manual
                        ? '¿Dónde va este apunte?'
                        : 'Resultados de clasificación',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    'Revisa cada carpeta y apunte antes de guardar. Un título claro ayuda a clasificar futuras fuentes.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                if (widget.manual)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: index == 0 || busy
                            ? null
                            : () => setState(() => index--),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('${index + 1} / ${widget.drafts.length}'),
                      IconButton(
                        onPressed: index + 1 >= widget.drafts.length || busy
                            ? null
                            : () => setState(() => index++),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                for (final d in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _card(d, lib),
                  ),
                if (widget.manual)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            final current = widget.drafts[index];
                            for (final d in widget.drafts.where(
                              (d) => !d.saved,
                            )) {
                              d.folderId = current.folderId;
                              d.noteId = current.noteId;
                              d.folderName = current.folderName;
                              d.noteTitle = current.noteTitle;
                            }
                          }),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text(
                      tr(context, 'Aplicar este destino a todo el lote'),
                    ),
                  ),
                const SizedBox(height: 12),
                Surface(
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          context,
                          widget.manual
                              ? 'Revisión de lote'
                              : 'El proceso terminó',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          context,
                          'Solo se guardarán las fuentes seleccionadas. Los resúmenes aparecerán al final del apunte, identificados con su modelo.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
