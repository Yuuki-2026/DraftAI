import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/note_document.dart';
import '../../notes/presentation/controller.dart';
import '../../notes/presentation/note_reader.dart';

class ExportRequest {
  final ExportOptions options;
  final bool separateFiles;
  const ExportRequest(this.options, this.separateFiles);
}

class ExportPreviewPage extends ConsumerStatefulWidget {
  final List<Note> notes;
  final ExportFormat format;
  const ExportPreviewPage({
    super.key,
    required this.notes,
    required this.format,
  });

  @override
  ConsumerState<ExportPreviewPage> createState() => _ExportPreviewPageState();
}

class _ExportPreviewPageState extends ConsumerState<ExportPreviewPage> {
  double titleSize = 24;
  double pageMargin = 36;
  bool showPageNumbers = true;
  bool includeDate = true;
  bool separateFiles = false;
  int previewIndex = 0;
  final imageWidths = <String, double>{};
  final imageAlignments = <String, String>{};
  final partOrders = <String, List<int>>{};
  late final TextEditingController footer;

  @override
  void initState() {
    super.initState();
    footer = TextEditingController();
  }

  @override
  void dispose() {
    footer.dispose();
    super.dispose();
  }

  void finish() => Navigator.pop(
    context,
    ExportRequest(
      ExportOptions(
        titleSize: titleSize,
        pageMargin: pageMargin,
        showPageNumbers: showPageNumbers,
        includeDate: includeDate,
        footer: footer.text.trim(),
        imageWidths: Map.of(imageWidths),
        imageAlignments: Map.of(imageAlignments),
        partOrder: {
          for (final entry in partOrders.entries)
            entry.key: List.of(entry.value),
        },
      ),
      separateFiles,
    ),
  );

  List<int> _partOrder(Note note) {
    final count = NoteDocument.parts(note).length;
    final current = partOrders[note.id];
    final seen = <int>{};
    return [
      if (current != null)
        for (final index in current)
          if (index >= 0 && index < count && seen.add(index)) index,
      for (var index = 0; index < count; index++)
        if (seen.add(index)) index,
    ];
  }

  void _reorderParts(Note note, int oldIndex, int newIndex) {
    final order = _partOrder(note);
    if (oldIndex < 0 || oldIndex >= order.length) return;
    if (newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, order.length - 1);
    final part = order.removeAt(oldIndex);
    order.insert(newIndex, part);
    setState(() => partOrders[note.id] = order);
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.notes[previewIndex];
    final formatName = widget.format == ExportFormat.pdf ? 'PDF' : 'Word';
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Vista previa de $formatName'))),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: FilledButton.icon(
            onPressed: finish,
            icon: const Icon(Icons.ios_share_outlined),
            label: Text(tr(context, 'Exportar')),
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 850,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                tr(context, 'Vista previa del documento'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.notes.length > 1) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      tooltip: tr(context, 'Apunte anterior'),
                      onPressed: previewIndex == 0
                          ? null
                          : () => setState(() => previewIndex--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${previewIndex + 1} / ${widget.notes.length} · ${note.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Siguiente apunte'),
                      onPressed: previewIndex >= widget.notes.length - 1
                          ? null
                          : () => setState(() => previewIndex++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AspectRatio(
                    aspectRatio: .72,
                    child: _PreviewSheet(
                      note: note,
                      titleSize: titleSize,
                      pageMargin: pageMargin,
                      showPageNumbers: showPageNumbers,
                      includeDate: includeDate,
                      footer: footer.text,
                      partOrder: _partOrder(note),
                      imageWidths: imageWidths,
                      imageAlignments: imageAlignments,
                      onReorder: (oldIndex, newIndex) =>
                          _reorderParts(note, oldIndex, newIndex),
                      onImageWidthChanged: (id, width) =>
                          setState(() => imageWidths[id] = width),
                      onImageAlignmentChanged: (id, alignment) =>
                          setState(() => imageAlignments[id] = alignment),
                    ),
                  ),
                ),
              ),
              if (widget.notes.length > 1) ...[
                const SizedBox(height: 16),
                SectionTitle('Exportar apuntes seleccionados'),
                Surface(
                  padding: EdgeInsets.zero,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.insert_drive_file_outlined),
                        label: Text(tr(context, 'Un documento')),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.file_copy_outlined),
                        label: Text(tr(context, 'Un archivo por apunte')),
                      ),
                    ],
                    selected: {separateFiles},
                    onSelectionChanged: (value) =>
                        setState(() => separateFiles = value.first),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SectionTitle('Personalizar documento'),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SliderControl(
                      title: 'Tamaño de títulos',
                      valueLabel: '${titleSize.round()} pt',
                      value: titleSize,
                      min: 16,
                      max: 36,
                      divisions: 10,
                      onChanged: (value) => setState(() => titleSize = value),
                    ),
                    _SliderControl(
                      title: 'Márgenes de página',
                      valueLabel: '${pageMargin.round()} pt',
                      value: pageMargin,
                      min: 18,
                      max: 72,
                      divisions: 9,
                      onChanged: (value) => setState(() => pageMargin = value),
                    ),
                    TextField(
                      controller: footer,
                      maxLength: 100,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: tr(context, 'Texto del pie de página'),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeDate,
                      onChanged: (value) =>
                          setState(() => includeDate = value ?? false),
                      title: Text(tr(context, 'Incluir fecha')),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: showPageNumbers,
                      onChanged: (value) =>
                          setState(() => showPageNumbers = value ?? false),
                      title: Text(tr(context, 'Mostrar número de página')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderControl extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _SliderControl({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(tr(context, title))),
          Text(valueLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );
}

class _PreviewSheet extends ConsumerWidget {
  final Note note;
  final double titleSize, pageMargin;
  final bool showPageNumbers, includeDate;
  final String footer;
  final List<int> partOrder;
  final Map<String, double> imageWidths;
  final Map<String, String> imageAlignments;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String id, double width) onImageWidthChanged;
  final void Function(String id, String alignment) onImageAlignmentChanged;
  const _PreviewSheet({
    required this.note,
    required this.titleSize,
    required this.pageMargin,
    required this.showPageNumbers,
    required this.includeDate,
    required this.footer,
    required this.partOrder,
    required this.imageWidths,
    required this.imageAlignments,
    required this.onReorder,
    required this.onImageWidthChanged,
    required this.onImageAlignmentChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = NoteDocument.parts(note);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 595).clamp(.55, .9).toDouble();
        final margin = pageMargin * scale;
        final contentWidth = (constraints.maxWidth - margin * 2)
            .clamp(40.0, constraints.maxWidth)
            .toDouble();
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (includeDate)
                    Text(
                      'DraftAI · ${note.createdAt.toLocal().toIso8601String().substring(0, 10)}',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 8 * scale,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: titleSize * scale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (note.topic.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      note.topic,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 10 * scale,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: EdgeInsets.zero,
                      itemCount: partOrder.length,
                      onReorder: onReorder,
                      itemBuilder: (context, index) {
                        final partIndex = partOrder[index];
                        final part = parts[partIndex];
                        final id = part.attachmentId;
                        final child = id != null
                            ? _PreviewAttachment(
                                note: note,
                                attachmentId: id,
                                widthFactor: imageWidths[id] ?? part.imageWidth,
                                alignment:
                                    imageAlignments[id] ?? part.imageAlignment,
                                maxWidth: contentWidth,
                                onWidthChanged: (width) =>
                                    onImageWidthChanged(id, width),
                                onAlignmentChanged: (alignment) =>
                                    onImageAlignmentChanged(id, alignment),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: NoteMathText(
                                  '${part.bullet ? '• ' : ''}${part.text}',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: part.heading > 0
                                        ? 11 * scale
                                        : 8.5 * scale,
                                    fontWeight: part.heading > 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    height: 1.35,
                                  ),
                                ),
                              );
                        return Material(
                          key: ValueKey('export-part-$partIndex'),
                          color: Colors.transparent,
                          child: part.attachmentId == null
                              ? child
                              : ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: child,
                                ),
                        );
                      },
                    ),
                  ),
                  if (footer.trim().isNotEmpty || showPageNumbers)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            footer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 7 * scale,
                            ),
                          ),
                        ),
                        if (showPageNumbers)
                          Text(
                            '1',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 7 * scale,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewAttachment extends ConsumerStatefulWidget {
  final Note note;
  final String attachmentId;
  final double widthFactor, maxWidth;
  final String alignment;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<String> onAlignmentChanged;
  const _PreviewAttachment({
    required this.note,
    required this.attachmentId,
    required this.widthFactor,
    required this.alignment,
    required this.maxWidth,
    required this.onWidthChanged,
    required this.onAlignmentChanged,
  });

  @override
  ConsumerState<_PreviewAttachment> createState() => _PreviewAttachmentState();
}

class _PreviewAttachmentState extends ConsumerState<_PreviewAttachment> {
  late Future<Uint8List>? imageBytes;
  late double widthFactor = widget.widthFactor;
  bool selected = false;

  @override
  void didUpdateWidget(covariant _PreviewAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.widthFactor != widget.widthFactor) {
      widthFactor = widget.widthFactor;
    }
    if (oldWidget.attachmentId != widget.attachmentId) imageBytes = _load();
  }

  @override
  void initState() {
    super.initState();
    imageBytes = _load();
  }

  Future<Uint8List>? _load() {
    final attachment = widget.note.attachments
        .where((value) => value.id == widget.attachmentId)
        .firstOrNull;
    if (attachment == null || !attachment.mime.startsWith('image/'))
      return null;
    return ref.read(mediaPort).read(attachment);
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.note.attachments
        .where((value) => value.id == widget.attachmentId)
        .firstOrNull;
    if (attachment == null || !attachment.mime.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          attachment == null ? '' : '[${attachment.name}]',
          style: const TextStyle(color: Colors.black54, fontSize: 9),
        ),
      );
    }
    return FutureBuilder<Uint8List>(
      future: imageBytes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 24);
        final width = (widget.maxWidth * widthFactor)
            .clamp(40.0, widget.maxWidth)
            .toDouble();
        final alignment = switch (widget.alignment) {
          'left' => Alignment.centerLeft,
          'right' => Alignment.centerRight,
          _ => Alignment.center,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              if (selected)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in [
                      (
                        'left',
                        Icons.format_align_left,
                        'Alinear a la izquierda',
                      ),
                      ('center', Icons.format_align_center, 'Centrar imagen'),
                      (
                        'right',
                        Icons.format_align_right,
                        'Alinear a la derecha',
                      ),
                    ])
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 26,
                        ),
                        tooltip: tr(context, option.$3),
                        onPressed: () => widget.onAlignmentChanged(option.$1),
                        icon: Icon(
                          option.$2,
                          size: 15,
                          color: widget.alignment == option.$1
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black54,
                        ),
                      ),
                    Tooltip(
                      message: tr(
                        context,
                        'Mantén pulsado y arrastra para mover',
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 17,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              Align(
                alignment: alignment,
                child: GestureDetector(
                  onTap: () => setState(() => selected = !selected),
                  child: SizedBox(
                    width: width,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.memory(
                            snapshot.data!,
                            width: constraints.maxWidth,
                            fit: BoxFit.contain,
                            cacheWidth: 420,
                          ),
                          if (selected)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (selected) ...[
                            _corner(
                              Alignment.topLeft,
                              horizontal: -1,
                              vertical: -1,
                            ),
                            _corner(
                              Alignment.topRight,
                              horizontal: 1,
                              vertical: -1,
                            ),
                            _corner(
                              Alignment.bottomLeft,
                              horizontal: -1,
                              vertical: 1,
                            ),
                            _corner(
                              Alignment.bottomRight,
                              horizontal: 1,
                              vertical: 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _corner(
    Alignment alignment, {
    required double horizontal,
    required double vertical,
  }) => Align(
    alignment: alignment,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => setState(() {
        final delta =
            (details.delta.dx * horizontal + details.delta.dy * vertical) /
            2 /
            widget.maxWidth;
        widthFactor = (widthFactor + delta).clamp(.2, 1).toDouble();
      }),
      onPanEnd: (_) => widget.onWidthChanged(widthFactor),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const SizedBox(width: 8, height: 8),
        ),
      ),
    ),
  );
}
