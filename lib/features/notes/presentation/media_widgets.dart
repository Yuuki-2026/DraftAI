import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/strings.dart';
import '../domain/entities.dart';
import '../domain/note_document.dart';
import 'controller.dart';

class NoteMediaEmbed extends q.EmbedBuilder {
  final List<Attachment> attachments;
  final bool editable;
  final void Function(String id, double width)? onResize;
  final void Function(String id, String alignment)? onAlign;
  const NoteMediaEmbed(
    this.attachments, {
    this.editable = false,
    this.onResize,
    this.onAlign,
  });
  @override
  String get key => NoteDocument.mediaKey;
  @override
  String toPlainText(dynamic node) => '';
  @override
  Widget build(BuildContext context, q.EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    final id = NoteDocument.mediaId(data);
    final a = attachments.where((a) => a.id == id).firstOrNull;
    if (a == null) return SizedBox.shrink();
    return EmbeddedMedia(
      attachment: a,
      gallery: attachments,
      widthFactor: NoteDocument.mediaWidth(data),
      alignment: NoteDocument.mediaAlignment(data),
      editable: editable && !embedContext.readOnly,
      onResize: onResize == null ? null : (width) => onResize!(a.id, width),
      onAlign: onAlign == null
          ? null
          : (alignment) => onAlign!(a.id, alignment),
    );
  }
}

class NoteTableEmbed extends q.EmbedBuilder {
  final ValueChanged<String>? onEdit;
  const NoteTableEmbed({this.onEdit});

  @override
  String get key => NoteDocument.tableKey;

  @override
  String toPlainText(dynamic node) => NoteDocument.tableText(node.value.data);

  @override
  Widget build(BuildContext context, q.EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    if (data is! String) return const SizedBox.shrink();
    return NoteTableView(
      data: data,
      onTap: !embedContext.readOnly && onEdit != null
          ? () => onEdit!(data)
          : null,
    );
  }
}

class NoteTableView extends StatelessWidget {
  final String data;
  final VoidCallback? onTap;
  const NoteTableView({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final rows = NoteDocument.tableRows(data);
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.fold<int>(
      0,
      (maximum, row) => row.length > maximum ? row.length : maximum,
    );
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth / columns).clamp(
            84.0,
            220.0,
          );
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: FixedColumnWidth(columnWidth),
                  border: TableBorder.all(
                    color: scheme.outlineVariant,
                    width: .8,
                  ),
                  children: [
                    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                      TableRow(
                        decoration: rowIndex == 0
                            ? BoxDecoration(
                                color: scheme.secondaryContainer.withValues(
                                  alpha: .42,
                                ),
                              )
                            : null,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Padding(
                              padding: const EdgeInsets.all(9),
                              child: Text(
                                column < rows[rowIndex].length
                                    ? rows[rowIndex][column]
                                    : '',
                                maxLines: 8,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: rowIndex == 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
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
      ),
    );
  }
}

class EmbeddedMedia extends ConsumerStatefulWidget {
  final Attachment attachment;
  final List<Attachment> gallery;
  final double widthFactor;
  final String alignment;
  final bool editable;
  final ValueChanged<double>? onResize;
  final ValueChanged<String>? onAlign;
  const EmbeddedMedia({
    super.key,
    required this.attachment,
    this.gallery = const [],
    this.widthFactor = 1,
    this.alignment = 'center',
    this.editable = false,
    this.onResize,
    this.onAlign,
  });
  @override
  ConsumerState<EmbeddedMedia> createState() => _EmbeddedMediaState();
}

class _EmbeddedMediaState extends ConsumerState<EmbeddedMedia> {
  Future<Uint8List>? imageBytes;
  late double widthFactor = widget.widthFactor;
  bool imageSelected = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant EmbeddedMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.widthFactor != widget.widthFactor) {
      widthFactor = widget.widthFactor;
    }
    if (oldWidget.attachment.id != widget.attachment.id) _loadImage();
    if (oldWidget.editable && !widget.editable) imageSelected = false;
  }

  void _loadImage() {
    imageBytes = widget.attachment.mime.startsWith('image/')
        ? ref.read(mediaPort).read(widget.attachment)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final gallery = widget.gallery;
    final isImage = attachment.mime.startsWith('image/');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: isImage
          ? FutureBuilder<Uint8List>(
              future: imageBytes,
              builder: (context, s) {
                if (s.hasError) {
                  return Text(tr(context, 'No se pudo abrir la imagen.'));
                }
                if (!s.hasData) {
                  return SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return TapRegion(
                  onTapOutside: (_) {
                    if (imageSelected && mounted) {
                      setState(() => imageSelected = false);
                    }
                  },
                  child: GestureDetector(
                    onDoubleTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ImageGallery(
                          images: gallery.isEmpty
                              ? [attachment]
                              : gallery
                                    .where((a) => a.mime.startsWith('image/'))
                                    .toList(),
                          initialId: attachment.id,
                          initialZoom: true,
                        ),
                      ),
                    ),
                    onTap: () {
                      if (widget.editable) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => imageSelected = !imageSelected);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ImageGallery(
                              images: gallery
                                  .where((a) => a.mime.startsWith('image/'))
                                  .toList(),
                              initialId: attachment.id,
                            ),
                          ),
                        );
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : 800.0;
                        final selected = widget.editable && imageSelected;
                        final imageAlignment = switch (widget.alignment) {
                          'left' => Alignment.centerLeft,
                          'right' => Alignment.centerRight,
                          _ => Alignment.center,
                        };
                        return Align(
                          alignment: imageAlignment,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: switch (widget.alignment) {
                              'left' => CrossAxisAlignment.start,
                              'right' => CrossAxisAlignment.end,
                              _ => CrossAxisAlignment.center,
                            },
                            children: [
                              if (selected)
                                _ImageAlignmentControls(
                                  alignment: widget.alignment,
                                  onChanged: widget.onAlign,
                                ),
                              SizedBox(
                                width: (width * widthFactor)
                                    .clamp(80.0, width)
                                    .toDouble(),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: selected
                                        ? Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: _ResizableMediaImage(
                                    bytes: s.data!,
                                    widthFactor: widthFactor,
                                    maxWidth: width,
                                    editable: selected,
                                    onResize: selected ? widget.onResize : null,
                                    onResizePreview: selected
                                        ? (value) => setState(
                                            () => widthFactor = value,
                                          )
                                        : null,
                                    cacheWidth:
                                        (width *
                                                MediaQuery.devicePixelRatioOf(
                                                  context,
                                                ))
                                            .round()
                                            .clamp(320, 1600)
                                            .toInt(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(
                  attachment.mime == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.description_outlined,
                  size: 18,
                ),
                label: Text(
                  tr(
                    context,
                    attachment.mime == 'application/pdf'
                        ? 'PDF adjunto'
                        : 'Documento adjunto',
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PdfAttachmentPage(attachment: attachment),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ImageAlignmentControls extends StatelessWidget {
  final String alignment;
  final ValueChanged<String>? onChanged;
  const _ImageAlignmentControls({
    required this.alignment,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in [
          ('left', Icons.format_align_left),
          ('center', Icons.format_align_center),
          ('right', Icons.format_align_right),
        ])
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 32),
            tooltip: tr(context, switch (option.$1) {
              'left' => 'Alinear a la izquierda',
              'right' => 'Alinear a la derecha',
              _ => 'Centrar imagen',
            }),
            onPressed: onChanged == null ? null : () => onChanged!(option.$1),
            icon: Icon(
              option.$2,
              size: 18,
              color: alignment == option.$1
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
      ],
    ),
  );
}

class _ResizableMediaImage extends StatefulWidget {
  final Uint8List bytes;
  final double widthFactor, maxWidth;
  final bool editable;
  final ValueChanged<double>? onResize;
  final ValueChanged<double>? onResizePreview;
  final int cacheWidth;
  const _ResizableMediaImage({
    required this.bytes,
    required this.widthFactor,
    required this.maxWidth,
    required this.editable,
    required this.onResize,
    required this.onResizePreview,
    required this.cacheWidth,
  });

  @override
  State<_ResizableMediaImage> createState() => _ResizableMediaImageState();
}

class _ResizableMediaImageState extends State<_ResizableMediaImage> {
  late double widthFactor = widget.widthFactor;

  @override
  void didUpdateWidget(covariant _ResizableMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.widthFactor != widget.widthFactor) {
      widthFactor = widget.widthFactor;
    }
  }

  Widget _handle(
    Alignment alignment, {
    required double horizontal,
    required double vertical,
  }) {
    final screenAnchor = switch (alignment) {
      Alignment.topLeft => (left: -8.0, right: null, top: -8.0, bottom: null),
      Alignment.topRight => (left: null, right: -8.0, top: -8.0, bottom: null),
      Alignment.bottomLeft => (
        left: -8.0,
        right: null,
        top: null,
        bottom: -8.0,
      ),
      _ => (left: null, right: -8.0, top: null, bottom: -8.0),
    };
    return Positioned(
      left: screenAnchor.left,
      right: screenAnchor.right,
      top: screenAnchor.top,
      bottom: screenAnchor.bottom,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => setState(() {
          final delta =
              (details.delta.dx * horizontal + details.delta.dy * vertical) /
              2 /
              widget.maxWidth;
          widthFactor = (widthFactor + delta).clamp(.2, 1).toDouble();
          widget.onResizePreview?.call(widthFactor);
        }),
        onPanEnd: (_) => widget.onResize?.call(widthFactor),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const SizedBox(width: 14, height: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Image.memory(
        widget.bytes,
        width: double.infinity,
        cacheWidth: widget.cacheWidth,
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            Text(tr(context, 'No se pudo abrir la imagen.')),
      ),
      if (widget.editable && widget.onResize != null) ...[
        _handle(Alignment.topLeft, horizontal: -1, vertical: -1),
        _handle(Alignment.topRight, horizontal: 1, vertical: -1),
        _handle(Alignment.bottomLeft, horizontal: -1, vertical: 1),
        _handle(Alignment.bottomRight, horizontal: 1, vertical: 1),
      ],
    ],
  );
}

class ImageGallery extends ConsumerStatefulWidget {
  final List<Attachment> images;
  final String initialId;
  final bool initialZoom;
  const ImageGallery({
    super.key,
    required this.images,
    required this.initialId,
    this.initialZoom = false,
  });
  @override
  ConsumerState<ImageGallery> createState() => _GalleryState();
}

class _GalleryState extends ConsumerState<ImageGallery> {
  late final PageController pages;
  late int index;
  bool zoomed = false;
  final loaded = <String, Future<Uint8List>>{};
  @override
  void initState() {
    super.initState();
    index = widget.images.indexWhere((a) => a.id == widget.initialId);
    if (index < 0) index = 0;
    pages = PageController(initialPage: index);
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, '${index + 1} / ${widget.images.length}')),
    ),
    body: SafeArea(
      child: PageView.builder(
        controller: pages,
        physics: zoomed ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: (v) => setState(() {
          index = v;
          zoomed = false;
        }),
        itemCount: widget.images.length,
        itemBuilder: (context, i) {
          final a = widget.images[i];
          return FutureBuilder<Uint8List>(
            future: loaded.putIfAbsent(a.id, () => ref.read(mediaPort).read(a)),
            builder: (context, s) => s.hasData
                ? _ZoomImage(
                    bytes: s.data!,
                    startZoomed: widget.initialZoom && a.id == widget.initialId,
                    onZoom: (value) {
                      if (i == index && value != zoomed) {
                        setState(() => zoomed = value);
                      }
                    },
                  )
                : Center(
                    child: s.hasError
                        ? Text(tr(context, 'No se pudo abrir la imagen.'))
                        : const CircularProgressIndicator(),
                  ),
          );
        },
      ),
    ),
  );
}

class _ZoomImage extends StatefulWidget {
  final Uint8List bytes;
  final ValueChanged<bool> onZoom;
  final bool startZoomed;
  const _ZoomImage({
    required this.bytes,
    required this.onZoom,
    this.startZoomed = false,
  });
  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  final transform = TransformationController();
  Offset tap = Offset.zero;
  @override
  void initState() {
    super.initState();
    if (widget.startZoomed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final size = context.size;
          if (size != null) _zoom(Offset(size.width / 2, size.height / 2));
        }
      });
    }
  }

  void _zoom(Offset point) {
    final zooming = transform.value.getMaxScaleOnAxis() <= 1.01;
    transform.value = zooming
        ? (Matrix4.diagonal3Values(3, 3, 1)
            ..setTranslationRaw(-point.dx * 2, -point.dy * 2, 0))
        : Matrix4.identity();
    widget.onZoom(zooming);
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => tap = details.localPosition,
    onDoubleTap: () => _zoom(tap),
    child: InteractiveViewer(
      transformationController: transform,
      minScale: 1,
      maxScale: 6,
      onInteractionEnd: (_) =>
          widget.onZoom(transform.value.getMaxScaleOnAxis() > 1.01),
      child: Center(child: Image.memory(widget.bytes, fit: BoxFit.contain)),
    ),
  );
}

class PdfAttachmentPage extends ConsumerStatefulWidget {
  final Attachment? attachment;
  final Uint8List? bytes;
  const PdfAttachmentPage({super.key, this.attachment, this.bytes})
    : assert(attachment != null || bytes != null);
  @override
  ConsumerState<PdfAttachmentPage> createState() => _PdfState();
}

class _PdfState extends ConsumerState<PdfAttachmentPage> {
  static const channel = MethodChannel('draftai/pdf');
  late final Future<(Uint8List, int)> info;
  final rendered = <int, Future<Uint8List?>>{};
  @override
  void initState() {
    super.initState();
    info = _load();
  }

  Future<(Uint8List, int)> _load() async {
    final bytes =
        widget.bytes ?? await ref.read(mediaPort).read(widget.attachment!);
    final count = await channel.invokeMethod<int>('info', {'bytes': bytes});
    return (bytes, count ?? 0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'PDF adjunto'))),
    body: FutureBuilder<(Uint8List, int)>(
      future: info,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Text(tr(context, 'No se pudo abrir el archivo.')),
          );
        }
        if (!s.hasData) return Center(child: CircularProgressIndicator());
        final (bytes, count) = s.data!;
        return ListView.builder(
          itemCount: count,
          itemBuilder: (context, i) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(tr(context, '${i + 1} / $count')),
              ),
              FutureBuilder<Uint8List?>(
                future: rendered.putIfAbsent(
                  i,
                  () => channel.invokeMethod<Uint8List>('render', {
                    'bytes': bytes,
                    'page': i,
                    'width': 1200,
                  }),
                ),
                builder: (context, page) => page.hasData
                    ? SizedBox(
                        height: MediaQuery.sizeOf(context).height * .8,
                        child: _ZoomImage(bytes: page.data!, onZoom: (_) {}),
                      )
                    : SizedBox(
                        height: 180,
                        child: Center(
                          child: page.hasError
                              ? Text(
                                  tr(context, 'No se pudo abrir el archivo.'),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void previewPickedFile(BuildContext context, PickedFile file) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => file.mime == 'application/pdf'
          ? PdfAttachmentPage(bytes: file.bytes)
          : Scaffold(
              appBar: AppBar(
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              body: SafeArea(
                child: file.mime.startsWith('image/')
                    ? _ZoomImage(bytes: file.bytes, onZoom: (_) {})
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: SelectableText(
                          utf8.decode(file.bytes, allowMalformed: true),
                        ),
                      ),
              ),
            ),
    ),
  );
}
