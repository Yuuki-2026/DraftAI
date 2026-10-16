import '../../../core/presentation/action_panel.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../domain/entities.dart';
import 'controller.dart';
import 'media_widgets.dart';
import 'note_format_bar.dart';
import 'rich_ai_text.dart';
import 'note_reader.dart';
import '../domain/ports.dart';
import '../../ai/presentation/connection_dialog.dart';
import '../domain/note_document.dart';
import '../domain/note_sections.dart';
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

class _NotePageState extends ConsumerState<NotePage> {
  late Note note;
  late TextEditingController title, topic;
  late q.QuillController editor;
  final focus = FocusNode();
  final scroll = ScrollController();
  final editorScroll = ScrollController();
  late String lastSignature;
  late Note committed;
  bool closing = false;
  late List<PickedFile> pendingFiles;
  bool inserting = false;
  bool aiBusy = false;
  bool reading = false;
  double readingScale = 1;
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
    note = widget.note;
    committed = note;
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
    final doc = q.Document.fromJson(
      NoteDocument.delta(NoteSections.compactDates(n)),
    );
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
    if (!dirty && mounted) setState(() => status = 'Cambios sin guardar');
    dirty = true;
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
    if (activeSave != null) {
      await activeSave;
    }
    if (!dirty) return true;
    final snapshot = NoteSections.stamp(_snapshot(), committed, DateTime.now());
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
      final stored =
          (await ref.read(notesPort).load()).active
              .where((n) => n.id == snapshot.id)
              .firstOrNull ??
          snapshot;
      note = stored;
      committed = stored;
      if (mounted && !dirty) {
        editor.removeListener(_changed);
        final oldEditor = editor;
        editor = _controller(stored);
        editor.readOnly = !editing;
        editor.addListener(_changed);
        lastSignature = _signature();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => oldEditor.dispose(),
        );
      }
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

  Future<bool> _resolveChanges() async {
    if (!dirty) return true;
    final decision = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, '¿Guardar los cambios?')),
        content: Text(tr(c, 'Tienes cambios sin guardar en este apunte.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, 'Seguir editando')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: Text(tr(c, 'Descartar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'save'),
            child: Text(tr(c, 'Guardar')),
          ),
        ],
      ),
    );
    if (!mounted || decision == null) return false;
    if (decision == 'save') return _flush();
    final oldIds = committed.attachments.map((a) => a.id).toSet();
    for (final a in note.attachments.where((a) => !oldIds.contains(a.id))) {
      await ref.read(mediaPort).delete(a);
    }
    if (!mounted) return false;
    title.removeListener(_changed);
    topic.removeListener(_changed);
    editor.removeListener(_changed);
    final oldEditor = editor;
    setState(() {
      note = committed;
      title.text = note.title;
      topic.text = note.topic;
      editor = _controller(note);
      editor.readOnly = !editing;
      dirty = false;
      lastSignature = _signature();
    });
    title.addListener(_changed);
    topic.addListener(_changed);
    editor.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => oldEditor.dispose());
    return true;
  }

  Future<void> _back() async {
    if (closing || saving || aiBusy) return;
    if (reading) {
      setState(() => reading = false);
      return;
    }
    closing = true;
    if (!await _resolveChanges() || !mounted) {
      closing = false;
      return;
    }
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _saveAndView() async {
    if (saving) return;
    if (dictating) {
      await ref.read(speechPort).stop();
      dictating = false;
    }
    focus.unfocus();
    editor.readOnly = true;
    final saved = await _flush();
    if (!mounted) return;
    setState(() {
      editing = !saved;
      editor.readOnly = saved;
    });
    if (saved) message(context, tr(context, 'Cambios guardados.'));
  }

  Future<void> _newTopic() async {
    var input = '';
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'Añadir tema')),
        content: TextField(
          onChanged: (value) => input = value,
          autofocus: true,
          maxLength: 120,
          decoration: InputDecoration(labelText: tr(c, 'Nombre del tema')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () {
              if (input.trim().isNotEmpty) {
                Navigator.pop(c, input.trim());
              }
            },
            child: Text(tr(c, 'Añadir')),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    final position = editor.document.length - 1;
    final text = '\n$name\n\n';
    editor.replaceText(
      position,
      0,
      text,
      TextSelection.collapsed(offset: position + text.length),
    );
    editor.formatText(position + 1, name.length, q.Attribute.h2);
    focus.requestFocus();
  }

  @override
  void dispose() {
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
                tr(
                  context,
                  editing
                      ? 'Editar apunte'
                      : reading
                      ? 'Modo lectura'
                      : note.title,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            if (!editing) const HeaderSearchActions(),
            if (editing)
              IconButton(
                tooltip: tr(context, 'Insertar'),
                onPressed: _insertMenu,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
              ),
            if (editing)
              TextButton(
                onPressed: saving ? null : _saveAndView,
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
                if (!editing)
                  Row(
                    children: [
                      Expanded(
                        child: Meta(
                          tr(context, 'Actualizado') +
                              ' ' +
                              dateLabel(note.updatedAt),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Exportar'),
                        onPressed: _export,
                        icon: const Icon(Icons.ios_share_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Lectura'),
                        onPressed: () => setState(() => reading = !reading),
                        icon: Icon(
                          reading ? Icons.menu_book : Icons.menu_book_outlined,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Más'),
                        onPressed: _more,
                        icon: const Icon(Icons.more_vert, size: 20),
                      ),
                    ],
                  ),
                if (reading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Reducir texto'),
                        onPressed: readingScale <= .85
                            ? null
                            : () => setState(() => readingScale -= .1),
                        icon: const Icon(Icons.text_decrease, size: 20),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Ampliar texto'),
                        onPressed: readingScale >= 1.65
                            ? null
                            : () => setState(() => readingScale += .1),
                        icon: const Icon(Icons.text_increase, size: 20),
                      ),
                    ],
                  ),
                if (saving || aiBusy) const LinearProgressIndicator(),
                if (dirty && !saving && status.startsWith('No se pudo'))
                  Text(status),
                if (editing)
                  TextField(
                    key: const Key('note-title'),
                    controller: title,
                    maxLength: 200,
                    buildCounter: (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Título del apunte'),
                    ),
                  )
                else
                  SelectableText(
                    title.text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                SizedBox(height: 12),
                if (editing &&
                    !NoteDocument.delta(note).any(
                      (o) =>
                          [1, 2].contains((o['attributes'] as Map?)?['header']),
                    ))
                  TextField(
                    controller: topic,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Tema'),
                      hintText: tr(context, 'Ej. Geometría diferencial'),
                    ),
                  )
                else if (topic.text.isNotEmpty &&
                    NoteSections.read(note).length <= 1)
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
                  TextButton.icon(
                    onPressed: inserting
                        ? null
                        : () async {
                            final files = List<PickedFile>.of(pendingFiles);
                            final insertion = editor.selection.extentOffset
                                .clamp(0, editor.document.length - 1);
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
                if (editing)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: saving ? null : _newTopic,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr(context, 'Añadir tema')),
                    ),
                  ),
                if (!editing &&
                    NoteSections.read(note).every(
                      (s) =>
                          !note.document.contains(NoteSections.label(s.date)),
                    ))
                  Meta(NoteSections.label(note.updatedAt.toLocal())),
                Surface(
                  key: const ValueKey('note-document-surface'),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        MediaQuery.textScalerOf(context)
                            .scale(reading ? readingScale : 1),
                      ),
                    ),
                    child: !editing
                        ? NoteReader(note: _snapshot())
                        : q.QuillEditor(
                            controller: editor,
                            focusNode: focus,
                            scrollController: editorScroll,
                            key: ValueKey((editor, editing)),
                            config: q.QuillEditorConfig(
                              customStyles: q.DefaultStyles(
                                paragraph: q.DefaultStyles.getInstance(context)
                                    .paragraph!
                                    .copyWith(
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(fontSize: 15, height: 1.6),
                                      verticalSpacing: const q.VerticalSpacing(
                                        3,
                                        7,
                                      ),
                                    ),
                                h3: q.DefaultStyles.getInstance(context).h3!
                                    .copyWith(
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(fontSize: 17, height: 1.5),
                                    ),
                              ),
                              textSpanBuilder:
                                  (
                                    c,
                                    node,
                                    offset,
                                    text,
                                    style,
                                    recognizer,
                                  ) => TextSpan(
                                    text: text,
                                    recognizer: recognizer,
                                    style:
                                        RegExp(r'^\d{2}/\d{2}/\d{4}$')
                                            .hasMatch(text.trim())
                                        ? (style ?? const TextStyle()).copyWith(
                                            fontSize: 11,
                                            height: 1.4,
                                            fontWeight: FontWeight.normal,
                                            color: Theme.of(c)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          )
                                        : style,
                                  ),
                              embedBuilders: [
                                NoteMediaEmbed(
                                  note.attachments
                                      .where(
                                        (a) => NoteDocument.references(
                                          jsonEncode(
                                            editor.document.toDelta().toJson(),
                                          ),
                                        ).contains(a.id),
                                      )
                                      .toList(),
                                ),
                              ],
                              scrollable: false,
                              autoFocus: false,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              placeholder: tr(
                                context,
                                'Escribe tus ideas aquí…',
                              ),
                              expands: false,
                              minHeight: 220,
                            ),
                          ),
                  ),
                ),
                if (note.lastAiModel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Meta(
                      '${tr(context, 'Texto mejorado por IA')} · ${note.lastAiModel}',
                    ),
                  ),
                if (note.summary.isNotEmpty) ...[
                  SectionTitle(
                    note.summaryModel.isNotEmpty
                        ? 'Resumen generado por IA'
                        : 'Resumen',
                  ),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Meta(
                          note.summaryModel.isEmpty
                              ? tr(
                                  context,
                                  'Modelo no registrado en esta versión anterior',
                                )
                              : note.summaryModel,
                        ),
                        const SizedBox(height: 8),
                        RichAiText(note.summary),
                      ],
                    ),
                  ),
                ],
                if (lib != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        Meta(tr(context, 'Guardado en')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lib.folders
                                    .where((f) => f.id == note.folderId)
                                    .firstOrNull
                                    ?.name ??
                                '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: reading
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.low
                        : Colors.white,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: editing
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NoteFormatBar(
                              controller: editor,
                              onFormula: _formula,
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

  Widget _location(Library lib) => DropdownButtonFormField<String>(
    initialValue: note.folderId,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: tr(context, 'Carpeta'),
      isDense: true,
    ),
    items: lib.folders
        .map(
          (f) => DropdownMenuItem(
            value: f.id,
            child: Row(
              children: [
                FolderGlyph(f.color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
    onChanged: (id) {
      if (id != null) {
        setState(() => note = note.copyWith(folderId: id, clearCategory: true));
        _changed();
      }
    },
  );

  Widget _tool(
    IconData icon,
    String label,
    VoidCallback action, {
    bool primary = false,
  }) => Expanded(
    child: Tooltip(
      message: tr(context, label),
      child: InkWell(
        onTap: action,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(primary ? 7 : 4),
                decoration: primary
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Icon(
                  icon,
                  size: primary ? 22 : 20,
                  color: primary
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // The normal note view keeps its actions; focused reading hides the bar.
  Widget _readingTools() => Row(
    children: [
      _tool(Icons.add, 'Nuevo', () async {
        if (await _resolveChanges() && mounted) {
          if (context.mounted) {
            await createNote(context, ref, folderId: note.folderId);
          }
        }
      }),
      _tool(Icons.edit_outlined, 'Editar', _enterEdit),
      _tool(Icons.auto_awesome_outlined, 'IA', _ai, primary: true),
      _tool(Icons.ios_share_outlined, 'Exportar', _export),
      _tool(Icons.more_vert, 'Más', _more),
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
        'Cámara',
        () => _attach(CaptureSource.camera),
      ),
      _tool(
        aiBusy ? Icons.hourglass_empty : Icons.auto_awesome_outlined,
        aiBusy ? 'Procesando…' : 'Mejorar',
        _improve,
      ),
      _tool(Icons.edit_outlined, 'Tipos', _types),
    ],
  );

  void _enterEdit() {
    focus.unfocus();
    setState(() {
      editing = true;
      reading = false;
      editor.readOnly = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && editing) focus.requestFocus();
    });
  }

  Future<void> _export() async {
    if (mounted && context.mounted) {
      await exportMenu(context, ref, [_snapshot()]);
    }
  }

  Future<void> _insertMenu() async {
    final source = await showModalBottomSheet<CaptureSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(tr(c, 'Insertar'))),
            for (final item in [
              (
                CaptureSource.gallery,
                Icons.photo_library_outlined,
                'Añadir imágenes',
              ),
              (CaptureSource.camera, Icons.camera_alt_outlined, 'Cámara'),
              (CaptureSource.files, Icons.attach_file, 'Archivos'),
            ])
              ListTile(
                leading: Icon(item.$2),
                title: Text(tr(c, item.$3)),
                onTap: () => Navigator.pop(c, item.$1),
              ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await _attach(source);
  }

  Future<void> _types() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(c, 'Tipos y formato')),
                trailing: IconButton(
                  tooltip: tr(c, 'Cerrar'),
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close),
                ),
              ),
              q.QuillSimpleToolbar(
                controller: editor,
                config: const q.QuillSimpleToolbarConfig(
                  multiRowsDisplay: true,
                  showFontFamily: true,
                  showFontSize: true,
                  showColorButton: true,
                  showBackgroundColorButton: false,
                  showBoldButton: false,
                  showItalicButton: false,
                  showSearchButton: false,
                  showLink: false,
                  showCodeBlock: false,
                  showInlineCode: false,
                  showIndent: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showUndo: false,
                  showRedo: false,
                  showAlignmentButtons: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _formula() async {
    var input = '';
    final selection = editor.selection;
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'Fórmula')),
        content: TextField(
          onChanged: (value) => input = value,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: r'\frac{a}{b} = \sqrt{x}',
            helperText: tr(
              c,
              'La fórmula se verá renderizada al guardar el apunte.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, input.trim()),
            child: Text(tr(c, 'Insertar')),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    final start = selection.start.clamp(0, editor.document.length - 1);
    final length =
        selection.end.clamp(start, editor.document.length - 1) - start;
    final formula = noteMathPattern.hasMatch(value)
        ? value
        : r'\(' + value + r'\)';
    editor.replaceText(
      start,
      length,
      formula,
      TextSelection.collapsed(offset: start + formula.length),
    );
  }

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
    if (aiBusy) return;
    final service = ref.read(aiPort);
    if (!service.configured) {
      if (service is! AiConnection ||
          !await connectAiDialog(context, service as AiConnection)) {
        return;
      }
      if (!mounted) return;
    }
    if (!mounted) return;
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
    setState(() => aiBusy = true);
    await runAction(context, () async {
      final result = await ref
          .read(controllerProvider.notifier)
          .transform(selected, AiAction.improve);
      if (!mounted) return;
      final model = aiModelLabel(ref.read(aiPort));
      final unchanged = result.trim() == selected.trim();
      var showOriginal = false;
      final accept = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (c) => StatefulBuilder(
          builder: (c, set) => SizedBox(
            height: MediaQuery.sizeOf(c).height * .84,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(c, 'Texto mejorado por IA'),
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(c, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Align(alignment: Alignment.centerLeft, child: Meta(model)),
                  const SizedBox(height: 12),
                  if (unchanged)
                    Text(
                      tr(
                        c,
                        'El modelo no propuso cambios para esta selección.',
                      ),
                    ),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(tr(c, 'Propuesta')),
                        selected: !showOriginal,
                        onSelected: (_) => set(() => showOriginal = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(tr(c, 'Original')),
                        selected: showOriginal,
                        onSelected: (_) => set(() => showOriginal = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: RichAiText(showOriginal ? selected : result),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(tr(c, 'Descartar')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: unchanged
                              ? null
                              : () => Navigator.pop(c, true),
                          child: Text(tr(c, 'Mantener')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
        note = note.copyWith(
          lastAiModel: model,
          lastAiAt: DateTime.now().toUtc(),
        );
        dirty = true;
        _changed();
      }
    });
    if (mounted) setState(() => aiBusy = false);
  }

  Future<void> _ai() async {
    if (!mounted) return;
    openPage(
      context,
      AiPage(
        initialNotes: [
          NoteSections.stamp(_snapshot(), committed, DateTime.now()),
        ],
        onInsert: (text, model) async {
          note = note.copyWith(summary: text, summaryModel: model);
          dirty = true;
          _enterEdit();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _history() async {
    if (!await _resolveChanges() || !mounted) return;
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
        committed = restored;
        title.removeListener(_changed);
        topic.removeListener(_changed);
        editor.removeListener(_changed);
        title.text = note.title;
        topic.text = note.topic;
        final oldEditor = editor;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => oldEditor.dispose(),
        );
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
    final action = await showActionPanel<String>(
      context,
      title: note.title,
      caption: 'ACCIONES · APUNTE',
      actions: const [
        PanelAction(
          'trash',
          'Enviar a la papelera',
          'Mover a eliminados',
          Icons.delete_outline,
        ),
        PanelAction(
          'edit',
          'Renombrar apunte',
          'Cambiar el título del apunte',
          Icons.edit_outlined,
        ),
        PanelAction('search', 'Buscar', 'Encontrar texto clave', Icons.search),
        PanelAction(
          'export',
          'Exportar',
          'Elegir formato de archivo',
          Icons.ios_share_outlined,
        ),
        PanelAction(
          'ai',
          'Generar resumen',
          'Resumir el apunte completo',
          Icons.auto_awesome_outlined,
        ),
        PanelAction(
          'history',
          'Historial y revertir cambios',
          'Ver versiones anteriores',
          Icons.history,
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'search') openPage(context, const SearchPage());
    if (action == 'export') await _export();
    if (action == 'ai') await _ai();
    if (action == 'edit') _enterEdit();
    if (action == 'history') await _history();
    if (action == 'trash' && await _resolveChanges() && mounted) {
      await runAction(context, () async {
        await ref.read(controllerProvider.notifier).trash(committed);
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
  final format = await showActionPanel<ExportFormat>(
    context,
    title: tr(context, 'Exportar como:'),
    caption: 'ACCIÓN RÁPIDA',
    choice: true,
    actions: const [
      PanelAction(
        ExportFormat.pdf,
        'PDF',
        'Documento estándar con imágenes',
        Icons.description_outlined,
        badge: '.pdf',
      ),
      PanelAction(
        ExportFormat.word,
        'Word',
        'Formato editable',
        Icons.description_outlined,
        badge: '.docx',
      ),
      PanelAction(
        ExportFormat.text,
        'Texto',
        'Archivo de texto plano',
        Icons.description_outlined,
        badge: '.txt',
      ),
      PanelAction(
        ExportFormat.markdown,
        'Markdown',
        'Compatible con editores de notas',
        Icons.subject,
        badge: '.md',
      ),
    ],
  );
  if (format == null || !context.mounted) return;
  final referenced = <String>{
    for (final n in notes)
      ...NoteDocument.parts(n).map((p) => p.attachmentId).whereType<String>(),
  };
  final excluded = {
    for (final n in notes)
      for (final a in n.attachments)
        if (referenced.contains(a.id) &&
            (format == ExportFormat.text ||
                format == ExportFormat.markdown ||
                !a.mime.startsWith('image/')))
          a.id: a,
  }.values.toList();
  final math = notes.any(
    (n) =>
        noteMathPattern.hasMatch(n.plainText) ||
        noteMathPattern.hasMatch(n.summary),
  );
  if (excluded.isEmpty && !math) {
    await runAction(context, () => ref.read(exportPort).export(notes, format));
    return;
  }
  final details = <String>[
    if (excluded.isNotEmpty)
      tr(context, 'No se incluirá el contenido de estos adjuntos:'),
    ...excluded.take(5).map((a) => '• ${a.name}'),
    if (excluded.length > 5)
      '${tr(context, "Y otros archivos")}: ${excluded.length - 5}',
    if (math)
      tr(
        context,
        'Las fórmulas se exportan como código LaTeX, sin el renderizado visual de la app.',
      ),
    tr(
      context,
      'El formato de texto puede simplificarse. Los originales seguirán disponibles en DraftAI.',
    ),
  ];
  final proceed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr(c, 'Antes de exportar')),
      content: SingleChildScrollView(child: Text(details.join('\n\n'))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(tr(c, 'Cancelar')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr(c, 'Exportar')),
        ),
      ],
    ),
  );
  if (proceed == true && context.mounted) {
    await runAction(context, () => ref.read(exportPort).export(notes, format));
  }
}
