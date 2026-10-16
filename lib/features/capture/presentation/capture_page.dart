import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import '../../notes/presentation/controller.dart';
import '../../ai/presentation/connection_dialog.dart';
import 'source_review.dart';

class CapturePage extends ConsumerStatefulWidget {
  final CaptureSource source;
  const CapturePage({super.key, this.source = CaptureSource.gallery});
  @override
  ConsumerState<CapturePage> createState() => _CaptureState();
}

class _CaptureState extends ConsumerState<CapturePage> {
  List<PickedFile> files = [];
  bool busy = false;
  int index = 0;
  final pages = PageController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick(widget.source));
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> _pick(CaptureSource source) async {
    if (busy) return;
    setState(() => busy = true);
    await runAction(context, () async {
      final added = await ref.read(mediaPort).pick(source);
      if (files.length + added.length > 20) {
        throw const AppFailure('El lote admite hasta 20 fuentes.');
      }
      if ([...files, ...added].fold<int>(0, (sum, f) => sum + f.bytes.length) >
          60 * 1024 * 1024) {
        throw const AppFailure('Divide el lote: admite hasta 60 MB en total.');
      }
      if (mounted) setState(() => files = [...files, ...added]);
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> _analyze() async {
    if (busy || files.isEmpty) return;
    final service = ref.read(aiPort);
    if (!service.configured) {
      if (service is! AiConnection ||
          !await connectAiDialog(context, service as AiConnection)) {
        return;
      }
      if (!mounted) return;
    }
    setState(() => busy = true);
    await runAction(context, () async {
      final access = await ref.read(controllerProvider.notifier).syncAiAccess();
      if (access != null && !access.vision) {
        throw const AppFailure(
          'Este acceso es Gratis. Conecta usando el código Pro de prueba para analizar imágenes, PDF y textos.',
        );
      }
      final groups = sourceGroups(files);
      if (access != null && groups.length > access.remaining) {
        throw AppFailure(
          'Este lote necesita ${groups.length} acciones y quedan ${access.remaining}. Reduce el lote o espera al próximo día.',
        );
      }
      if (!mounted) return;
      if (!await confirm(
        context,
        'Analizar fuentes',
        'Se enviarán ${files.length} fuentes y los nombres de tus carpetas/apuntes al servicio de IA. '
            'Se procesarán en ${groups.length} grupos de hasta 5. Revisarás cada destino antes de guardar.',
      )) {
        return;
      }
      if (!mounted) return;
      final lib = ref.read(libraryProvider).value ?? const Library([], [], []);
      final results = await Navigator.push<List<SourceDraft>>(
        context,
        MaterialPageRoute(
          builder: (_) => SourceAnalysisPage(groups: groups, library: lib),
        ),
      );
      if (results != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SourceReviewPage(drafts: results),
          ),
        );
        if (mounted) {
          setState(() {
            final saved = results
                .where((d) => d.saved)
                .map((d) => d.file)
                .toSet();
            files.removeWhere(saved.contains);
            index = 0;
          });
        }
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> _manual() async {
    final lib = ref.read(libraryProvider).value ?? const Library([], [], []);
    final drafts = files.map((f) => SourceDraft.manual(f, lib)).toList();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SourceReviewPage(manual: true, drafts: drafts),
      ),
    );
    if (!mounted) return;
    setState(() {
      final saved = drafts.where((d) => d.saved).map((d) => d.file).toSet();
      files.removeWhere(saved.contains);
      index = 0;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Captura'))),
    body: SafeArea(
      child: ResponsiveBody(
        maxWidth: 760,
        child: ListView(
          children: [
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr(context, 'Captura completada'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Pill('${files.length} ${tr(context, 'elementos')}'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tr(context, '¿Dónde irán tus fotos?'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, 'Asigna cada fuente a una carpeta y a un apunte.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (files.isNotEmpty)
              Surface(
                radius: 16,
                child: Column(
                  children: [
                    SizedBox(
                      height: 210,
                      child: PageView.builder(
                        controller: pages,
                        itemCount: files.length,
                        onPageChanged: (i) => setState(() => index = i),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            Center(
                              child: files[i].mime.startsWith('image/')
                                  ? Image.memory(
                                      files[i].bytes,
                                      fit: BoxFit.contain,
                                      cacheWidth: 900,
                                    )
                                  : Icon(
                                      files[i].mime == 'application/pdf'
                                          ? Icons.picture_as_pdf_outlined
                                          : Icons.text_snippet_outlined,
                                      size: 64,
                                    ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                tooltip: tr(context, 'Quitar adjunto'),
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        files.removeAt(i);
                                        index = index.clamp(
                                          0,
                                          files.isEmpty ? 0 : files.length - 1,
                                        );
                                      }),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Meta(
                      '${index + 1} / ${files.length} ${tr(context, 'fuentes')}',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Surface(
              radius: 16,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(
                  tr(context, 'Déjalo a la IA'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Lectura, resumen interno y destino sugerido por fuente',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy || files.isEmpty ? null : _analyze,
              ),
            ),
            const SizedBox(height: 12),
            Surface(
              radius: 16,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  tr(context, 'Hazlo tú'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  tr(context, 'Elige carpeta y apunte para cada archivo'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy || files.isEmpty ? null : _manual,
              ),
            ),
            const SizedBox(height: 12),
            Meta(
              tr(
                context,
                'Hasta 20 fuentes por lote. La IA procesa grupos de hasta 5 y 10 MB; PDF de hasta 12 páginas, TXT/MD y fotos.',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(CaptureSource.gallery),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(tr(context, 'Añadir otra')),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(CaptureSource.files),
                  icon: const Icon(Icons.attach_file),
                  label: Text(tr(context, 'Archivos')),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: Text(tr(context, 'Descartar lote')),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
