import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../domain/entities.dart';
import 'controller.dart';
import 'library_page.dart';
import '../../ai/presentation/ai_pages.dart';

class NotePage extends ConsumerStatefulWidget {
  final Note note;
  final bool edit;
  const NotePage({super.key, required this.note, this.edit = false});
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
  Timer? debounce;
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
  }

  q.QuillController _controller(Note n) {
    q.Document doc;
    try {
      doc = n.document.isEmpty
          ? q.Document.fromJson([
              {'insert': '${n.plainText}\n'},
            ])
          : q.Document.fromJson(jsonDecode(n.document) as List);
    } catch (_) {
      doc = q.Document.fromJson([
        {'insert': '${n.plainText}\n'},
      ]);
    }
    return q.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _changed() {
    if (!editing) return;
    dirty = true;
    debounce?.cancel();
    if (mounted) setState(() => status = 'Cambios sin guardar');
    debounce = Timer(const Duration(milliseconds: 900), () => _flush());
  }

  Note _snapshot() => note.copyWith(
    title: title.text.trim().isEmpty ? 'Sin tÃ­tulo' : title.text,
    topic: topic.text,
    document: jsonEncode(editor.document.toDelta().toJson()),
    plainText: editor.document.toPlainText().trimRight(),
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
        status = 'Guardandoâ€¦';
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
    title.dispose();
    topic.dispose();
    editor.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value;
    final folder = lib?.folders.where((f) => f.id == note.folderId).firstOrNull;
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Meta('DraftAI'),
              Text(
                editing ? 'Editar apunte' : 'Vista del apunte',
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
                          focus.unfocus();
                        }
                      },
                child: const Text('Guardar'),
              ),
            IconButton(
              tooltip: 'Historial de versiones',
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(editing ? 'Modo borrador activo' : 'Apunte guardado'),
                    Pill(status),
                  ],
                ),
                const SizedBox(height: 14),
                if (editing)
                  TextField(
                    key: const Key('note-title'),
                    controller: title,
                    maxLength: 200,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: const InputDecoration(
                      labelText: 'TÃ­tulo de la sesiÃ³n',
                    ),
                  )
                else
                  SelectableText(
                    title.text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                const SizedBox(height: 10),
                Meta(
                  '${dateLabel(note.createdAt)} Â· ${_snapshot().words} palabras',
                ),
                const SizedBox(height: 12),
                if (editing)
                  TextField(
                    controller: topic,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Tema',
                      hintText: 'Ej. GeometrÃ­a diferencial',
                    ),
                  )
                else if (topic.text.isNotEmpty)
                  Pill(topic.text),
                const SizedBox(height: 10),
                if (editing && lib != null)
                  _location(lib)
                else
                  Text(
                    'Guardado en ${folder?.name ?? 'tu biblioteca'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                if (editing)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
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
                      ],
                    ),
                  ),
                q.QuillEditor(
                  controller: editor,
                  focusNode: focus,
                  scrollController: ScrollController(),
                  config: q.QuillEditorConfig(
                    scrollable: false,
                    autoFocus: false,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    placeholder: 'Escribe tus ideas aquÃ­â€¦',
                    expands: false,
                    minHeight: 220,
                  ),
                ),
                if (note.attachments.isNotEmpty)
                  const SectionTitle('ImÃ¡genes y archivos'),
                for (final a in note.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AttachmentView(
                      attachment: a,
                      onRemove: !editing
                          ? null
                          : () => setState(() {
                              note = note.copyWith(
                                attachments: note.attachments
                                    .where((v) => v.id != a.id)
                                    .toList(),
                              );
                              _changed();
                            }),
                    ),
                  ),
                if (editing)
                  OutlinedButton.icon(
                    onPressed: () => _attach(CaptureSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('AÃ±adir imÃ¡genes'),
                  ),
                if (note.summary.isNotEmpty) ...[
                  const SectionTitle('Resumen interno'),
                  Surface(child: SelectableText(note.summary)),
                ],
                const SizedBox(height: 24),
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
            child: editing ? _editingTools() : _readingTools(),
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
          const DropdownMenuItem(
            value: '',
            child: Text('Sin categorÃ­a', style: TextStyle(fontSize: 12)),
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
        child: const Text('+ CategorÃ­a'),
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
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ),
  );
  Widget _readingTools() => Row(
    children: [
      _tool(
        Icons.add,
        'Nuevo',
        () => createNote(context, ref, folderId: note.folderId),
      ),
      _tool(
        Icons.edit_outlined,
        'Editar',
        () => setState(() {
          editing = true;
          editor.readOnly = false;
        }),
      ),
      _tool(
        Icons.auto_stories_outlined,
        'Lectura',
        () => message(
          context,
          'Modo de solo lectura activo. Toca Editar para modificar el apunte.',
        ),
      ),
      _tool(
        Icons.ios_share,
        'Exportar',
        () => exportMenu(context, ref, [_snapshot()]),
      ),
      _tool(Icons.more_horiz, 'MÃ¡s', _more),
    ],
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
        'CÃ¡mara',
        () => _attach(CaptureSource.camera),
      ),
      _tool(Icons.auto_awesome_outlined, 'Mejorar', _improve),
      _tool(Icons.psychology_outlined, 'IA', _ai),
      _tool(Icons.attach_file, 'Archivos', () => _attach(CaptureSource.files)),
    ],
  );
  Future<void> _attach(CaptureSource source) async {
    await runAction(context, () async {
      final files = await ref.read(mediaPort).pick(source);
      final added = <Attachment>[];
      for (final f in files) {
        added.add(await ref.read(mediaPort).store(f));
      }
      if (!mounted) return;
      setState(() {
        note = note.copyWith(attachments: [...note.attachments, ...added]);
        _changed();
      });
      await _flush();
    });
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
            'El dictado no estÃ¡ disponible. Revisa el permiso de micrÃ³fono.',
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
    final end = selection.end.clamp(0, full.length);
    final selected = start == end ? full : full.substring(start, end);
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
                : 'DemostraciÃ³n Â· limpieza de texto',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Meta('ORIGINAL'),
                SelectableText(selected),
                const Divider(),
                const Meta('PROPUESTA'),
                SelectableText(result),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Descartar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Reemplazar texto'),
            ),
          ],
        ),
      );
      if (accept == true && mounted) {
        editor.replaceText(
          start == end ? 0 : start,
          start == end ? full.length - 1 : end - start,
          result,
          const TextSelection.collapsed(offset: 0),
        );
        await _flush();
      }
    });
  }

  Future<void> _ai() async {
    if (!await _flush() || !mounted) return;
    openPage(
      context,
      AiPage(
        initialNotes: [_snapshot()],
        onInsert: (text) async {
          final end = editor.document.length - 1;
          editor.replaceText(
            end,
            0,
            '\n$text\n',
            TextSelection.collapsed(offset: end),
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
                const ListTile(title: Text('Versiones anteriores')),
                if (history.isEmpty)
                  const ListTile(
                    title: Text('TodavÃ­a no hay versiones anteriores.'),
                  ),
                ...history.map(
                  (r) => ListTile(
                    title: Text(r.note.title),
                    subtitle: Text(
                      '${dateLabel(r.note.updatedAt)} Â· ${r.reason}',
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
        'Restaurar versiÃ³n',
        'La versiÃ³n actual quedarÃ¡ guardada en el historial.',
      )) {
        return;
      }
      final restored = chosen.note.copyWith(
        restore: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await ref
          .read(controllerProvider.notifier)
          .save(restored, reason: 'RestauraciÃ³n de historial');
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
              title: const Text('Herramientas de IA'),
              onTap: () => Navigator.pop(c, 'ai'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Renombrar o mover'),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial y revertir cambios'),
              onTap: () => Navigator.pop(c, 'history'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Enviar a la papelera'),
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

class AttachmentView extends ConsumerStatefulWidget {
  final Attachment attachment;
  final VoidCallback? onRemove;
  const AttachmentView({super.key, required this.attachment, this.onRemove});
  @override
  ConsumerState<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends ConsumerState<AttachmentView> {
  late Future<Uint8List> bytes;
  @override
  void initState() {
    super.initState();
    bytes = ref.read(mediaPort).read(widget.attachment);
  }

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.attachment.mime.startsWith('image/'))
          FutureBuilder<Uint8List>(
            future: bytes,
            builder: (c, s) => s.hasError
                ? const Text('No se pudo abrir la imagen.')
                : s.hasData
                ? InkWell(
                    onTap: () => openPage(
                      context,
                      Scaffold(
                        appBar: AppBar(title: Text(widget.attachment.name)),
                        body: Center(
                          child: InteractiveViewer(
                            maxScale: 6,
                            child: Image.memory(s.data!),
                          ),
                        ),
                      ),
                    ),
                    child: Image.memory(
                      s.data!,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Text('Formato de imagen no compatible.'),
                    ),
                  )
                : const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          )
        else
          Icon(
            widget.attachment.mime == 'application/pdf'
                ? Icons.picture_as_pdf_outlined
                : Icons.description_outlined,
            size: 40,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Meta(widget.attachment.name)),
            if (widget.onRemove != null)
              IconButton(
                tooltip: 'Quitar adjunto',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ],
    ),
  );
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
          const ListTile(
            title: Text('Exportar como'),
            subtitle: Text(
              'El archivo compartido podrÃ¡ leerse fuera de DraftAI.',
            ),
          ),
          for (final entry in [
            (
              ExportFormat.pdf,
              'PDF Â· documento con imÃ¡genes',
              Icons.picture_as_pdf_outlined,
            ),
            (
              ExportFormat.word,
              'Word Â· documento editable',
              Icons.description_outlined,
            ),
            (
              ExportFormat.text,
              'Texto Â· archivo .txt',
              Icons.text_snippet_outlined,
            ),
            (ExportFormat.markdown, 'Markdown Â· archivo .md', Icons.code),
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
