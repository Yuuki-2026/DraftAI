import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import '../../notes/domain/note_document.dart';
import '../../notes/presentation/controller.dart';
import '../../notes/presentation/note_page.dart';
import '../../settings/presentation/settings_pages.dart';

class CapturePage extends ConsumerStatefulWidget {
  final CaptureSource source;
  const CapturePage({super.key, this.source = CaptureSource.gallery});
  @override
  ConsumerState<CapturePage> createState() => _CaptureState();
}

class _CaptureState extends ConsumerState<CapturePage> {
  List<PickedFile> files = [];
  String? folderId, noteId;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick(widget.source));
  }

  Future<void> _pick(CaptureSource source) async {
    if (busy) return;
    setState(() => busy = true);
    await runAction(context, () async {
      final picked = await ref.read(mediaPort).pick(source);
      if (files.length + picked.length > 20) {
        throw const AppFailure('El lote admite hasta 20 archivos.');
      }
      if (mounted) setState(() => files = [...files, ...picked]);
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save(Library lib) async {
    if (busy || files.isEmpty) return;
    setState(() => busy = true);
    await runAction(context, () async {
      final ctrl = ref.read(controllerProvider.notifier);
      Note? destination = lib.active.where((n) => n.id == noteId).firstOrNull;
      if (destination == null) {
        var folder = folderId ?? lib.folders.firstOrNull?.id;
        if (folder == null) {
          final f = Folder(
            ctrl.newId(),
            tr(context, 'Mis apuntes'),
            0xFFFFFFFF,
          );
          await ctrl.folder(f);
          folder = f.id;
        }
        destination = await ctrl.create(folder);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              NotePage(note: destination!, edit: true, pendingFiles: files),
        ),
      );
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> _analyze(Library lib) async {
    if (!(ref.read(controllerProvider).value?.pro ?? false)) {
      openPage(context, const PlansPage());
      return;
    }
    if (files.isEmpty) return;
    if (files.length > 5 || files.any((f) => !f.mime.startsWith('image/'))) {
      message(context, 'Selecciona hasta 5 imágenes para su lectura.');
      return;
    }
    if (!await confirm(
      context,
      'Analizar imágenes',
      'Se enviarán las imágenes al proveedor para transcribir su contenido. Revisarás la propuesta antes de guardar.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await runAction(context, () async {
      final proposal = await ref
          .read(controllerProvider.notifier)
          .analyze(files, lib);
      if (mounted) {
        openPage(context, ProposalPage(files: files, proposal: proposal));
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value ?? const Library([], [], []);
    final currentFolder = folderId ?? lib.folders.firstOrNull?.id;
    final notes = lib.active.where((n) => n.folderId == currentFolder).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, '¿Dónde irán tus fotos?'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 760,
          child: ListView(
            children: [
              SizedBox(height: 16),
              if (files.isNotEmpty)
                SizedBox(
                  height: 230,
                  child: PageView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, i) => Stack(
                      children: [
                        Center(
                          child: files[i].mime.startsWith('image/')
                              ? Image.memory(
                                  files[i].bytes,
                                  fit: BoxFit.contain,
                                )
                              : const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 56,
                                ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            tooltip: tr(context, 'Quitar adjunto'),
                            onPressed: busy
                                ? null
                                : () => setState(() => files.removeAt(i)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Pill(
                            tr(context, '${i + 1} / ${files.length}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: currentFolder,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'Tus carpetas'),
                ),
                items: lib.folders
                    .map(
                      (f) => DropdownMenuItem(value: f.id, child: Text(f.name)),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        folderId = v;
                        noteId = null;
                      }),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('note-$currentFolder'),
                initialValue: noteId ?? '',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'Nota de destino'),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(tr(context, 'Crear una nota nueva')),
                  ),
                  ...notes.map(
                    (n) => DropdownMenuItem(
                      value: n.id,
                      child: Text(
                        n.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() => noteId = v == '' ? null : v),
              ),
              SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy || files.isEmpty ? null : () => _save(lib),
                icon: const Icon(Icons.edit_note),
                label: Text(tr(context, 'Continuar en el editor')),
              ),
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy || files.isEmpty ? null : () => _analyze(lib),
                icon: const Icon(Icons.auto_awesome),
                label: Text(tr(context, 'Analizar imágenes')),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : () => _pick(CaptureSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(tr(context, 'Añadir otra')),
                  ),
                  TextButton.icon(
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
              SizedBox(height: 24),
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
  late TextEditingController title, topic, text, summary, folder;
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
  }

  @override
  void dispose() {
    for (final c in [title, topic, text, summary, folder]) {
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
      final attachments = <Attachment>[];
      for (final file in widget.files) {
        attachments.add(await ref.read(mediaPort).store(file));
      }
      final now = DateTime.now().toUtc();
      final note = Note(
        id: ctrl.newId(),
        folderId: f.id,
        title: title.text.trim(),
        topic: topic.text,
        plainText: text.text,
        document: jsonEncode([
          ...NoteDocument.formatted(text.text),
          for (final a in attachments) ...[
            {
              'insert': {NoteDocument.mediaKey: a.id},
            },
            {'insert': '\n'},
          ],
        ]),
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
    appBar: AppBar(title: Text(tr(context, 'Revisar clasificación'))),
    body: SafeArea(
      child: ResponsiveBody(
        maxWidth: 720,
        child: ListView(
          children: [
            SizedBox(height: 16),
            if (widget.proposal.demonstration)
              Surface(
                child: Text(
                  tr(
                    context,
                    'Demostración de interfaz: no se ha leído el contenido de las imágenes. Puedes editar los campos antes de guardar.',
                  ),
                ),
              ),
            SectionTitle('Propuesta de organización'),
            for (final field in [
              (title, 'Título'),
              (topic, 'Tema'),
              (folder, 'Carpeta existente o nueva'),
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
              decoration: InputDecoration(
                labelText: tr(context, 'Texto extraído · revisa su exactitud'),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: summary,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: tr(context, 'Resumen interno'),
              ),
            ),
            SizedBox(height: 18),
            FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: const Icon(Icons.done_all, size: 18),
              label: Text(busy ? 'Guardando…' : 'Aplicar cambios y guardar'),
            ),
            SizedBox(height: 28),
          ],
        ),
      ),
    ),
  );
}
