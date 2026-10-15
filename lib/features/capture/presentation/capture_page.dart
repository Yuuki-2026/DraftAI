import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import '../../notes/presentation/controller.dart';
import '../../notes/presentation/note_page.dart';
import '../../notes/presentation/library_page.dart';
import '../../settings/presentation/settings_pages.dart';

class CapturePage extends ConsumerStatefulWidget {
  final CaptureSource source;
  const CapturePage({super.key, this.source = CaptureSource.gallery});
  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  List<PickedFile> files = [];
  bool busy = false, analyzing = false;
  String? folderId;
  final perFile = <int, String>{};
  final perCategory = <int, String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick(widget.source));
  }

  Future<void> _pick(CaptureSource source) async {
    setState(() => busy = true);
    await runAction(context, () async {
      final picked = await ref.read(mediaPort).pick(source);
      if (mounted) {
        setState(() => files = [...files, ...picked].take(20).toList());
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<String> _defaultFolder(Library lib) async {
    if (folderId != null) return folderId!;
    if (lib.folders.isNotEmpty) return lib.folders.first.id;
    final ctrl = ref.read(controllerProvider.notifier);
    final folder = Folder(ctrl.newId(), 'Mis apuntes', 0xFFFFFFFF);
    await ctrl.folder(folder);
    return folder.id;
  }

  Future<void> _save(Library lib) async {
    setState(() => busy = true);
    await runAction(context, () async {
      final defaultId = await _defaultFolder(lib);
      Note? first;
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final attachment = await ref.read(mediaPort).store(f);
        final ctrl = ref.read(controllerProvider.notifier);
        final now = DateTime.now().toUtc();
        final note = Note(
          id: ctrl.newId(),
          folderId: perFile[i] ?? defaultId,
          categoryId: perCategory[i],
          title: f.name,
          plainText: f.mime == 'text/plain'
              ? utf8.decode(f.bytes, allowMalformed: true)
              : '',
          attachments: [attachment],
          createdAt: now,
          updatedAt: now,
        );
        await ctrl.save(note, reason: 'Importación');
        first ??= note;
      }
      if (mounted && first != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => NotePage(note: first!)),
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> _analyze(Library lib) async {
    if (!(ref.read(controllerProvider).value?.pro ?? false)) {
      openPage(context, const PlansPage());
      return;
    }
    if (ref.read(aiPort).configured &&
        !await confirm(
          context,
          'Enviar imágenes a la IA',
          'Se enviarán los archivos seleccionados y los nombres de tus carpetas y categorías para proponer su organización. El guardado solo ocurre cuando confirmes.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      analyzing = true;
    });
    await runAction(context, () async {
      final proposal = await ref
          .read(controllerProvider.notifier)
          .analyze(files, lib);
      if (!mounted) return;
      openPage(context, ProposalPage(files: files, proposal: proposal));
    });
    if (mounted) {
      setState(() {
        busy = false;
        analyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value ?? const Library([], [], []);
    final pro = ref.watch(controllerProvider).value?.pro ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('¿Dónde irán tus fotos?')),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 760,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Text(
                'Captura y organización',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Revisa cada archivo antes de incorporarlo a tus apuntes.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _pick(CaptureSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Cámara'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _pick(CaptureSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Imágenes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _pick(CaptureSource.files),
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Archivos'),
                  ),
                ],
              ),
              SectionTitle('${files.length} archivos seleccionados'),
              if (busy)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        analyzing
                            ? 'Analizando archivos…'
                            : 'Preparando archivos…',
                      ),
                    ],
                  ),
                ),
              if (files.isEmpty && !busy)
                const Surface(
                  child: Text(
                    'Añade imágenes, PDF o texto. Cada archivo puede pesar hasta 15 MB; máximo 20 por lote.',
                  ),
                ),
              for (var i = 0; i < files.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (files[i].mime.startsWith('image/'))
                          Image.memory(
                            files[i].bytes,
                            height: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported_outlined,
                              size: 48,
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                files[i].name,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar archivo',
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      files.removeAt(i);
                                      perFile.clear();
                                      perCategory.clear();
                                    }),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                        Meta(byteLabel(files[i].bytes.length)),
                        if (lib.folders.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: perFile[i] ?? lib.folders.first.id,
                            decoration: const InputDecoration(
                              labelText: 'Carpeta',
                            ),
                            items: lib.folders
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f.id,
                                    child: Text(
                                      f.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) => setState(() {
                                    perFile[i] = v!;
                                    perCategory.remove(i);
                                  }),
                          ),
                        if (lib.categories
                            .where(
                              (c) =>
                                  c.folderId ==
                                  (perFile[i] ?? lib.folders.firstOrNull?.id),
                            )
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey('cat_${i}_${perFile[i]}'),
                            initialValue: perCategory[i] ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Sin categoría'),
                              ),
                              ...lib.categories
                                  .where(
                                    (c) =>
                                        c.folderId ==
                                        (perFile[i] ??
                                            lib.folders.firstOrNull?.id),
                                  )
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  ),
                            ],
                            onChanged: busy
                                ? null
                                : (v) => setState(() {
                                    if (v == '') {
                                      perCategory.remove(i);
                                    } else {
                                      perCategory[i] = v!;
                                    }
                                  }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: busy ? null : () => editFolder(context, ref),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Crear otra carpeta'),
              ),
              if (files.isNotEmpty) ...[
                const SectionTitle('¿Cómo quieres continuar?'),
                FilledButton.icon(
                  onPressed: busy ? null : () => _save(lib),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Hazlo tú · guardar sin OCR'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _analyze(lib),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(pro ? 'Déjalo a la IA' : 'Déjalo a la IA · Pro'),
                ),
                const SizedBox(height: 8),
                Text(
                  pro ? 'La clasificación siempre requiere tu revisión.' : 'Gratis conserva las imágenes como adjuntos. No extrae texto.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class ProposalPage extends ConsumerStatefulWidget {
  final List<PickedFile> files;
  final AnalysisProposal proposal;
  const ProposalPage({super.key, required this.files, required this.proposal});
  @override
  ConsumerState<ProposalPage> createState() => _ProposalPageState();
}

class _ProposalPageState extends ConsumerState<ProposalPage> {
  late TextEditingController title, topic, text, summary, folder, category;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    title = TextEditingController(text: p.title);
    topic = TextEditingController(text: p.topic);
    text = TextEditingController(text: p.text);
    summary = TextEditingController(text: p.summary);
    folder = TextEditingController(text: p.folderName);
    category = TextEditingController(text: p.categoryName);
  }

  @override
  void dispose() {
    for (final c in [title, topic, text, summary, folder, category]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty || folder.text.trim().isEmpty) {
      message(context, 'Escribe el título y la carpeta.');
      return;
    }
    setState(() => busy = true);
    await runAction(context, () async {
      final lib = ref.read(libraryProvider).value!;
      final ctrl = ref.read(controllerProvider.notifier);
      var f = lib.folders
          .where(
            (f) => f.name.toLowerCase() == folder.text.trim().toLowerCase(),
          )
          .firstOrNull;
      if (f == null) {
        f = Folder(ctrl.newId(), folder.text.trim(), 0xFFFFFFFF);
        await ctrl.folder(f);
      }
      Category? cat;
      if (category.text.trim().isNotEmpty) {
        cat = lib.categories
            .where(
              (c) =>
                  c.folderId == f!.id &&
                  c.name.toLowerCase() == category.text.trim().toLowerCase(),
            )
            .firstOrNull;
        if (cat == null) {
          cat = Category(ctrl.newId(), f.id, category.text.trim());
          await ctrl.category(cat);
        }
      }
      final attachments = <Attachment>[];
      for (final file in widget.files) {
        attachments.add(await ref.read(mediaPort).store(file));
      }
      final now = DateTime.now().toUtc();
      final note = Note(
        id: ctrl.newId(),
        folderId: f.id,
        categoryId: cat?.id,
        title: title.text.trim(),
        topic: topic.text,
        plainText: text.text,
        summary: summary.text,
        attachments: attachments,
        createdAt: now,
        updatedAt: now,
      );
      await ctrl.save(note, reason: 'Propuesta revisada');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => NotePage(note: note)),
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar clasificación')),
    body: SafeArea(
      child: ResponsiveBody(
        maxWidth: 720,
        child: ListView(
          children: [
            const SizedBox(height: 16),
            if (widget.proposal.demonstration)
              const Surface(
                child: Text(
                  'Demostración de interfaz: no se ha leído el contenido de las imágenes. Puedes editar los campos antes de guardar.',
                ),
              ),
            const SectionTitle('Propuesta de organización'),
            for (final field in [
              (title, 'Título'),
              (topic, 'Tema'),
              (folder, 'Carpeta existente o nueva'),
              (category, 'Categoría existente o nueva'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: field.$1,
                  maxLength: field.$1 == title ? 200 : 80,
                  decoration: InputDecoration(labelText: field.$2),
                ),
              ),
            TextField(
              controller: text,
              minLines: 5,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'Texto extraído · revisa su exactitud',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: summary,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Resumen interno'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: const Icon(Icons.done_all, size: 18),
              label: Text(busy ? 'Guardando…' : 'Aplicar cambios y guardar'),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    ),
  );
}
