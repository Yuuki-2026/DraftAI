import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../domain/entities.dart';
import 'controller.dart';
import 'media_widgets.dart';
import '../domain/note_document.dart';
import '../../../core/presentation/strings.dart';
import 'library_page.dart';
import '../../ai/presentation/ai_pages.dart';

class NotePage extends ConsumerStatefulWidget {
  final Note note;
  final bool edit;
  final List<PickedFile> pendingFiles;
  const NotePage({
    super.key,
    required this.note,
    this.edit = false,
    this.pendingFiles = const [],
  });
  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage>
    with WidgetsBindingObserver {
  late Note note;
  late TextEditingController title, topic;
  late q.QuillController editor;
  final focus = FocusNode();
  final scroll = ScrollController();
  final editorScroll = ScrollController();
  late String lastSignature;
  Timer? debounce;
  late List<PickedFile> pendingFiles;
  bool inserting = false;
  bool editing = false,
      dirty = false,
      saving = false,
      allowPop = false,
      dictating = false;
  Future<bool>? activeSave;
  String status = 'Guardado en este dispositivo';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    note = widget.note;
    editing = widget.edit;
    title = TextEditingController(text: note.title);
    topic = TextEditingController(text: note.topic);
    editor = _controller(note);
    editor.readOnly = !editing;
    title.addListener(_changed);
    topic.addListener(_changed);
    editor.addListener(_changed);
    lastSignature = _signature();
    pendingFiles = List.of(widget.pendingFiles);
  }

  q.QuillController _controller(Note n) {
    final doc = q.Document.fromJson(NoteDocument.delta(n));
    return q.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  String _signature() => jsonEncode([
    title.text,
    topic.text,
    editor.document.toDelta().toJson(),
    note.folderId,
    note.categoryId,
    note.attachments.map((a) => a.id).toList(),
  ]);
  void _changed() {
    if (!editing) return;
    final signature = _signature();
    if (signature == lastSignature) return;
    lastSignature = signature;
    dirty = true;
    debounce?.cancel();
    if (mounted) setState(() => status = 'Cambios sin guardar');
    debounce = Timer(const Duration(milliseconds: 900), () => _flush());
  }

  Note _snapshot() => note.copyWith(
    title: title.text.trim().isEmpty ? 'Sin título' : title.text,
    topic: topic.text,
    document: jsonEncode(editor.document.toDelta().toJson()),
    documentVersion: 2,
    plainText: editor.document
        .toPlainText()
        .replaceAll('\uFFFC', '')
        .trimRight(),
    updatedAt: DateTime.now().toUtc(),
  );
  Future<bool> _flush() async {
    debounce?.cancel();
    if (activeSave != null) {
      await activeSave;
    }
    if (!dirty) return true;
    final snapshot = _snapshot();
    dirty = false;
    final future = _persist(snapshot);
    activeSave = future;
    final result = await future;
    activeSave = null;
    return result;
  }

  Future<bool> _persist(Note snapshot) async {
    if (mounted) {
      setState(() {
        saving = true;
        status = 'Guardando…';
      });
    }
    try {
      await ref.read(controllerProvider.notifier).save(snapshot);
      note = snapshot;
      if (mounted) {
        setState(() {
          saving = false;
          status = dirty
              ? 'Cambios sin guardar'
              : 'Guardado en este dispositivo';
        });
      }
      return true;
    } catch (e) {
      dirty = true;
      if (mounted) {
        setState(() {
          saving = false;
          status = 'No se pudo guardar. Toca Guardar para reintentar.';
        });
      }
      if (mounted) message(context, '$e');
      return false;
    }
  }

  Future<void> _back() async {
    if (!await _flush() || !mounted) {
      return;
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    if (dictating) {
      ref.read(speechPort).stop();
    }
    title.dispose();
    topic.dispose();
    editor.dispose();
    focus.dispose();
    scroll.dispose();
    editorScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value;

    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: tr(context, 'Volver'),
            onPressed: _back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Meta(tr(context, 'DraftAI')),
              Text(
                tr(context, editing ? 'Editar apunte' : 'Vista del apunte'),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            if (editing)
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (await _flush() && mounted) {
                          setState(() {
                            editing = false;
                            editor.readOnly = true;
                          });
                          if (context.mounted) {
                            FocusScope.of(context).unfocus();
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && scroll.hasClients) scroll.jumpTo(0);
                          });
                        }
                      },
                child: Text(tr(context, 'Guardar')),
              ),
            if (editing)
              IconButton(
                tooltip: tr(context, 'Historial de versiones'),
                onPressed: _history,
                icon: const Icon(Icons.history, size: 22),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ResponsiveBody(
            maxWidth: 840,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                if (saving) const LinearProgressIndicator(),
                if (dirty && !saving && status.startsWith('No se pudo'))
                  Text(status),
                if (editing)
                  TextField(
                    key: const Key('note-title'),
                    controller: title,
                    maxLength: 200,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Título de la sesión'),
                    ),
                  )
                else
                  SelectableText(
                    title.text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                SizedBox(height: 10),
                Meta(
                  tr(
                    context,
                    '${dateLabel(note.createdAt)} · ${_snapshot().words} palabras',
                  ),
                ),
                SizedBox(height: 12),
                if (editing)
                  TextField(
                    controller: topic,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Tema'),
                      hintText: tr(context, 'Ej. Geometría diferencial'),
                    ),
                  )
                else if (topic.text.isNotEmpty)
                  Pill(topic.text),
                SizedBox(height: 10),
                if (editing && lib != null) _location(lib),
                SizedBox(height: 16),
                if (editing && pendingFiles.isNotEmpty) ...[
                  Text(
                    tr(
                      context,
                      'Toca una línea del texto y luego pulsa Insertar.',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final files = List<PickedFile>.of(pendingFiles);
                      final insertion = editor.selection.extentOffset.clamp(
                        0,
                        editor.document.length - 1,
                      );
                      await runAction(context, () async {
                        await _insertFiles(files, at: insertion);
                        if (mounted) setState(() => pendingFiles = []);
                      });
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      tr(context, 'Insertar ${pendingFiles.length} archivos'),
                    ),
                  ),
                ],
                q.QuillEditor(
                  controller: editor,
                  focusNode: focus,
                  scrollController: editorScroll,
                  config: q.QuillEditorConfig(
                    embedBuilders: [
                      NoteMediaEmbed(
                        note.attachments
                            .where(
                              (a) => NoteDocument.references(
                                jsonEncode(editor.document.toDelta().toJson()),
                              ).contains(a.id),
                            )
                            .toList(),
                      ),
                    ],
                    scrollable: false,
                    autoFocus: false,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    placeholder: 'Escribe tus ideas aquí…',
                    expands: false,
                    minHeight: 220,
                  ),
                ),
                if (editing)
                  OutlinedButton.icon(
                    onPressed: () => _attach(CaptureSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(tr(context, 'Añadir imágenes')),
                  ),
                if (note.summary.isNotEmpty) ...[
                  SectionTitle('Resumen interno'),
                  Surface(child: SelectableText(note.summary)),
                ],
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: editing
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      q.QuillSimpleToolbar(
                        controller: editor,
                        config: const q.QuillSimpleToolbarConfig(
                          multiRowsDisplay: false,
                          showFontFamily: true,
                          showFontSize: true,
                          showColorButton: true,
                          showBackgroundColorButton: false,
                          showSearchButton: false,
                          showLink: false,
                          showCodeBlock: false,
                          showInlineCode: false,
                          showQuote: true,
                          showIndent: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showListCheck: true,
                          showClearFormat: true,
                          showAlignmentButtons: false,
                        ),
                      ),
                      _editingTools(),
                    ],
                  )
                : _readingTools(),
          ),
        ),
      ),
    );
  }

  Widget _location(Library lib) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      DropdownButton<String>(
        value: note.folderId,
        isDense: true,
        items: lib.folders
            .map(
              (f) => DropdownMenuItem(
                value: f.id,
                child: SizedBox(
                  width: 160,
                  child: Text(
                    f.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (id) {
          if (id != null) {
            setState(() {
              note = note.copyWith(folderId: id, clearCategory: true);
              _changed();
            });
          }
        },
      ),
      DropdownButton<String>(
        value: note.categoryId ?? '',
        isDense: true,
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(
              tr(context, 'Sin categoría'),
              style: TextStyle(fontSize: 12),
            ),
          ),
          ...lib.categories
              .where((c) => c.folderId == note.folderId)
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, style: const TextStyle(fontSize: 12)),
                ),
              ),
        ],
        onChanged: (id) => setState(() {
          note = note.copyWith(categoryId: id, clearCategory: id == '');
          _changed();
        }),
      ),
      TextButton(
        onPressed: () {
          final f = lib.folders.firstWhere((f) => f.id == note.folderId);
          editCategory(context, ref, f);
        },
        child: Text(tr(context, '+ Categoría')),
      ),
    ],
  );
  Widget _tool(IconData icon, String label, VoidCallback action) => Expanded(
    child: InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            SizedBox(height: 5),
            Text(tr(context, label), style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ),
  );
  Widget _readingTools() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: tr(context, 'Volver'),
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        FilledButton.icon(
          onPressed: _ai,
          icon: const Icon(Icons.auto_awesome),
          label: Text(tr(context, 'IA')),
        ),
        IconButton(
          tooltip: tr(context, 'Más'),
          onPressed: _more,
          icon: const Icon(Icons.more_horiz),
        ),
      ],
    ),
  );
  Widget _editingTools() => Row(
    children: [
      _tool(
        dictating ? Icons.stop_circle_outlined : Icons.mic_none,
        dictating ? 'Detener' : 'Dictar',
        _dictate,
      ),
      _tool(
        Icons.camera_alt_outlined,
        'Cámara',
        () => _attach(CaptureSource.camera),
      ),
      _tool(Icons.auto_awesome_outlined, 'Mejorar', _improve),
      _tool(Icons.psychology_outlined, 'IA', _ai),
      _tool(Icons.attach_file, 'Archivos', () => _attach(CaptureSource.files)),
    ],
  );
  Future<void> _attach(CaptureSource source) async {
    // Save selection before opening a native picker, which can move focus.
    final insertion = editor.selection.extentOffset.clamp(
      0,
      editor.document.length - 1,
    );
    await runAction(context, () async {
      final files = await ref.read(mediaPort).pick(source);
      await _insertFiles(files, at: insertion);
    });
  }

  Future<void> _insertFiles(List<PickedFile> files, {int? at}) async {
    if (files.isEmpty || inserting) return;
    setState(() => inserting = true);
    final added = <Attachment>[];
    try {
      for (final f in files) {
        added.add(await ref.read(mediaPort).store(f));
      }
    } catch (_) {
      for (final a in added) {
        await ref.read(mediaPort).delete(a);
      }
      if (mounted) setState(() => inserting = false);
      rethrow;
    }
    if (!mounted) return;
    setState(
      () => note = note.copyWith(attachments: [...note.attachments, ...added]),
    );
    var position = (at ?? editor.selection.extentOffset).clamp(
      0,
      editor.document.length - 1,
    );
    for (var i = 0; i < added.length; i++) {
      final a = added[i];
      if (files[i].mime == 'text/plain') {
        final text = utf8.decode(files[i].bytes, allowMalformed: true);
        editor.replaceText(
          position,
          0,
          '$text\n',
          TextSelection.collapsed(offset: position + text.length + 1),
        );
        position += text.length + 1;
      } else {
        editor.replaceText(
          position,
          0,
          '\n',
          TextSelection.collapsed(offset: position + 1),
        );
        position++;
        editor.replaceText(
          position,
          0,
          q.BlockEmbed(NoteDocument.mediaKey, a.id),
          TextSelection.collapsed(offset: position + 1),
        );
        position++;
        editor.replaceText(
          position,
          0,
          '\n',
          TextSelection.collapsed(offset: position + 1),
        );
        position++;
      }
    }
    dirty = true;
    _changed();
    await _flush();
    if (mounted) setState(() => inserting = false);
  }

  Future<void> _dictate() async {
    await runAction(context, () async {
      if (dictating) {
        await ref.read(speechPort).stop();
        if (mounted) setState(() => dictating = false);
        return;
      }
      final start = editor.selection.baseOffset.clamp(
        0,
        editor.document.length - 1,
      );
      var previous = 0;
      final ok = await ref.read(speechPort).listen((text) {
        if (!mounted) return;
        editor.replaceText(
          start,
          previous,
          text,
          TextSelection.collapsed(offset: start + text.length),
        );
        previous = text.length;
      });
      if (mounted) {
        setState(() => dictating = ok);
        if (!ok) {
          message(
            context,
            'El dictado no está disponible. Revisa el permiso de micrófono.',
          );
        }
      }
    });
  }

  Future<void> _improve() async {
    if (!await _flush() || !mounted) return;
    final selection = editor.selection;
    final full = editor.document.toPlainText();
    final start = selection.start.clamp(0, full.length);
    final end = selection.end.clamp(0, full.length - 1);
    if (start == end) {
      message(context, tr(context, 'Selecciona el texto que quieres mejorar.'));
      return;
    }
    final originalSignature = jsonEncode(editor.document.toDelta().toJson());
    final selected = full.substring(start, end);
    if (selected.contains('\uFFFC')) {
      message(context, 'Selecciona solo texto para mejorarlo.');
      return;
    }
    if (ref.read(aiPort).configured &&
        !await confirm(
          context,
          'Procesar con IA',
          'Se enviará únicamente el texto seleccionado al servicio de IA. ¿Continuar?',
        )) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () async {
      final result = await ref
          .read(controllerProvider.notifier)
          .transform(selected, AiAction.improve);
      if (!mounted) return;
      final accept = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            ref.read(aiPort).configured
                ? 'Texto mejorado'
                : 'Demostración · limpieza de texto',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Meta(tr(context, 'ORIGINAL')),
                SelectableText(selected),
                const Divider(),
                Meta(tr(context, 'PROPUESTA')),
                SelectableText(result),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(context, 'Descartar')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(context, 'Reemplazar texto')),
            ),
          ],
        ),
      );
      if (accept == true && mounted) {
        if (jsonEncode(editor.document.toDelta().toJson()) !=
            originalSignature) {
          message(
            context,
            tr(context, 'Contenido modificado. Vuelve a seleccionar el texto.'),
          );
          return;
        }
        if (RegExp(r'^#{1,3} |^[-*] ', multiLine: true).hasMatch(result)) {
          final delta = q.Document.fromJson(NoteDocument.formatted(result))
              .toDelta();
          editor.replaceText(start, end - start, delta, null);
          editor.updateSelection(
            TextSelection.collapsed(
              offset: (start + delta.length).clamp(
                0,
                editor.document.length - 1,
              ),
            ),
            q.ChangeSource.local,
          );
        } else {
          editor.replaceText(
            start,
            end - start,
            result,
            TextSelection.collapsed(offset: start + result.length),
          );
        }
        await _flush();
      }
    });
  }

  Future<void> _ai() async {
    if (!await _flush() || !mounted) return;
    final insertion = editor.selection.extentOffset.clamp(
      0,
      editor.document.length - 1,
    );
    openPage(
      context,
      AiPage(
        initialNotes: [_snapshot()],
        onInsert: (text) async {
          final position = insertion.clamp(0, editor.document.length - 1);
          final delta = q.Document.fromJson(NoteDocument.formatted('\n$text'))
              .toDelta();
          editor.replaceText(position, 0, delta, null);
          editor.updateSelection(
            TextSelection.collapsed(
              offset: (position + delta.length).clamp(
                0,
                editor.document.length - 1,
              ),
            ),
            q.ChangeSource.local,
          );
          dirty = true;
          await _flush();
        },
      ),
    );
  }

  Future<void> _history() async {
    if (!await _flush() || !mounted) {
      return;
    }
    await runAction(context, () async {
      final history = await ref
          .read(controllerProvider.notifier)
          .history(note.id);
      if (!mounted) return;
      final chosen = await showModalBottomSheet<Revision>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .65,
            child: ListView(
              children: [
                ListTile(title: Text(tr(context, 'Versiones anteriores'))),
                if (history.isEmpty)
                  ListTile(
                    title: Text(
                      tr(context, 'Todavía no hay versiones anteriores.'),
                    ),
                  ),
                ...history.map(
                  (r) => ListTile(
                    title: Text(r.note.title),
                    subtitle: Text(
                      tr(
                        context,
                        '${dateLabel(r.note.updatedAt)} · ${r.reason}',
                      ),
                    ),
                    trailing: const Icon(Icons.restore),
                    onTap: () => Navigator.pop(c, r),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (chosen == null || !mounted) return;
      if (!await confirm(
        context,
        'Restaurar versión',
        'La versión actual quedará guardada en el historial.',
      )) {
        return;
      }
      final restored = chosen.note.copyWith(
        restore: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await ref
          .read(controllerProvider.notifier)
          .save(restored, reason: 'Restauración de historial');
      if (!mounted) return;
      setState(() {
        note = restored;
        title.removeListener(_changed);
        topic.removeListener(_changed);
        editor.removeListener(_changed);
        title.text = note.title;
        topic.text = note.topic;
        editor.dispose();
        editor = _controller(note);
        editor.readOnly = !editing;
        editor.addListener(_changed);
        title.addListener(_changed);
        topic.addListener(_changed);
        dirty = false;
        lastSignature = _signature();
      });
    });
  }

  Future<void> _more() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(tr(context, 'Herramientas de IA')),
              onTap: () => Navigator.pop(c, 'ai'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(tr(context, 'Renombrar o mover')),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(tr(context, 'Historial y revertir cambios')),
              onTap: () => Navigator.pop(c, 'history'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(tr(context, 'Enviar a la papelera')),
              onTap: () => Navigator.pop(c, 'trash'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'ai') await _ai();
    if (action == 'edit') {
      setState(() {
        editing = true;
        editor.readOnly = false;
      });
    }
    if (action == 'history') await _history();
    if (action == 'trash' && await _flush() && mounted) {
      await runAction(context, () async {
        await ref.read(controllerProvider.notifier).trash(note);
        if (mounted) {
          setState(() => allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      });
    }
  }
}

class AttachmentView extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onRemove;
  const AttachmentView({super.key, required this.attachment, this.onRemove});
  @override
  Widget build(BuildContext context) =>
      EmbeddedMedia(attachment: attachment, gallery: [attachment]);
}

Future<void> exportMenu(
  BuildContext context,
  WidgetRef ref,
  List<Note> notes,
) async {
  final format = await showModalBottomSheet<ExportFormat>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(tr(context, 'Exportar como')),
            subtitle: Text(
              tr(
                context,
                'El archivo compartido podrá leerse fuera de DraftAI.',
              ),
            ),
          ),
          for (final entry in [
            (
              ExportFormat.pdf,
              'PDF · documento con imágenes',
              Icons.picture_as_pdf_outlined,
            ),
            (
              ExportFormat.word,
              'Word · documento editable',
              Icons.description_outlined,
            ),
            (
              ExportFormat.text,
              'Texto · archivo .txt',
              Icons.text_snippet_outlined,
            ),
            (ExportFormat.markdown, 'Markdown · archivo .md', Icons.code),
          ])
            ListTile(
              leading: Icon(entry.$3),
              title: Text(entry.$2),
              onTap: () => Navigator.pop(c, entry.$1),
            ),
        ],
      ),
    ),
  );
  if (format != null && context.mounted) {
    await runAction(context, () => ref.read(exportPort).export(notes, format));
  }
}
