
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
  const NoteMediaEmbed(this.attachments);
  @override
  String get key => NoteDocument.mediaKey;
  @override
  String toPlainText(dynamic node) => '';
  @override
  Widget build(BuildContext context, q.EmbedContext embedContext) {
    final a = attachments
        .where((a) => a.id == embedContext.node.value.data)
        .firstOrNull;
    if (a == null) return const SizedBox.shrink();
    return EmbeddedMedia(attachment: a, gallery: attachments);
  }
}

class EmbeddedMedia extends ConsumerWidget {
  final Attachment attachment;
  final List<Attachment> gallery;
  const EmbeddedMedia({
    super.key,
    required this.attachment,
    this.gallery = const [],
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = attachment.mime.startsWith('image/');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: image
          ? FutureBuilder<Uint8List>(
              future: ref.read(mediaPort).read(attachment),
              builder: (context, s) {
                if (s.hasError) {
                  return Text(tr(context, 'No se pudo abrir la imagen.'));
                }
                if (!s.hasData) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ImageGallery(
                        images: gallery
                            .where((a) => a.mime.startsWith('image/'))
                            .toList(),
                        initialId: attachment.id,
                      ),
                    ),
                  ),
                  child: Image.memory(
                    s.data!,
                    fit: BoxFit.fitWidth,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        Text(tr(context, 'No se pudo abrir la imagen.')),
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

class ImageGallery extends ConsumerStatefulWidget {
  final List<Attachment> images;
  final String initialId;
  const ImageGallery({
    super.key,
    required this.images,
    required this.initialId,
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
    appBar: AppBar(title: Text('${index + 1} / ${widget.images.length}')),
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
  const _ZoomImage({required this.bytes, required this.onZoom});
  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTap: () {
      transform.value = Matrix4.identity();
      widget.onZoom(false);
    },
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
  final Attachment attachment;
  const PdfAttachmentPage({super.key, required this.attachment});
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
    final bytes = await ref.read(mediaPort).read(widget.attachment);
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
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final (bytes, count) = s.data!;
        return ListView.builder(
          itemCount: count,
          itemBuilder: (context, i) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${i + 1} / $count'),
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
                    ? InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Image.memory(page.data!),
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
