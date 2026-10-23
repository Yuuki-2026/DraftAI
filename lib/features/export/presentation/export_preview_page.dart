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
  double imageScale = 1;
  double titleSize = 24;
  double pageMargin = 36;
  bool showPageNumbers = true;
  bool includeDate = true;
  bool separateFiles = false;
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
        imageScale: imageScale,
        titleSize: titleSize,
        pageMargin: pageMargin,
        showPageNumbers: showPageNumbers,
        includeDate: includeDate,
        footer: footer.text.trim(),
      ),
      separateFiles,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final note = widget.notes.first;
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
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AspectRatio(
                    aspectRatio: .72,
                    child: _PreviewSheet(
                      note: note,
                      imageScale: imageScale,
                      titleSize: titleSize,
                      pageMargin: pageMargin,
                      showPageNumbers: showPageNumbers,
                      includeDate: includeDate,
                      footer: footer.text,
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
                      title: 'Tamaño de las imágenes',
                      valueLabel: '${(imageScale * 100).round()}%',
                      value: imageScale,
                      min: .4,
                      max: 1.5,
                      divisions: 11,
                      onChanged: (value) => setState(() => imageScale = value),
                    ),
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
  final double imageScale, titleSize, pageMargin;
  final bool showPageNumbers, includeDate;
  final String footer;
  const _PreviewSheet({
    required this.note,
    required this.imageScale,
    required this.titleSize,
    required this.pageMargin,
    required this.showPageNumbers,
    required this.includeDate,
    required this.footer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = NoteDocument.parts(note).take(8).toList();
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
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final part in parts)
                          if (part.attachmentId case final id?)
                            _PreviewAttachment(
                              note: note,
                              attachmentId: id,
                              imageScale: imageScale,
                              widthFactor: part.imageWidth,
                              alignment: part.imageAlignment,
                              maxWidth: contentWidth,
                            )
                          else
                            Padding(
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
                            ),
                      ],
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
  final double imageScale, widthFactor, maxWidth;
  final String alignment;
  const _PreviewAttachment({
    required this.note,
    required this.attachmentId,
    required this.imageScale,
    required this.widthFactor,
    required this.alignment,
    required this.maxWidth,
  });

  @override
  ConsumerState<_PreviewAttachment> createState() => _PreviewAttachmentState();
}

class _PreviewAttachmentState extends ConsumerState<_PreviewAttachment> {
  late Future<Uint8List>? imageBytes;

  @override
  void initState() {
    super.initState();
    imageBytes = _load();
  }

  @override
  void didUpdateWidget(covariant _PreviewAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachmentId != widget.attachmentId) imageBytes = _load();
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
        return Align(
          alignment: switch (widget.alignment) {
            'left' => Alignment.centerLeft,
            'right' => Alignment.centerRight,
            _ => Alignment.center,
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Image.memory(
              snapshot.data!,
              width: (widget.maxWidth * widget.imageScale * widget.widthFactor)
                  .clamp(40, widget.maxWidth)
                  .toDouble(),
              height: 86,
              fit: BoxFit.contain,
              cacheWidth: 420,
            ),
          ),
        );
      },
    );
  }
}
