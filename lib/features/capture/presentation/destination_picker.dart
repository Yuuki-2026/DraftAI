import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/entities.dart';
import '../../notes/presentation/controller.dart';
import '../../notes/presentation/media_widgets.dart';
import 'source_draft.dart';

class DestinationPicker extends ConsumerStatefulWidget {
  final List<SourceDraft> drafts;
  final bool reviewOnly;
  final Future<void> Function(List<SourceDraft>) onComplete;
  const DestinationPicker({
    super.key,
    required this.drafts,
    required this.onComplete,
    this.reviewOnly = false,
  });
  @override
  ConsumerState<DestinationPicker> createState() => _DestinationState();
}

class _DestinationState extends ConsumerState<DestinationPicker> {
  late final List<SourceDraft> drafts;
  final search = TextEditingController();
  int index = 0, step = 0;
  final reviewed = <int>{};
  bool busy = false, voice = false, createFolder = false;
  SourceDraft get current => drafts[index];
  @override
  void initState() {
    super.initState();
    drafts = widget.drafts.map(SourceDraft.clone).toList();
  }

  @override
  void dispose() {
    if (voice) ref.read(speechPort).stop();
    search.dispose();
    super.dispose();
  }

  String norm(String value) {
    var out = value.toLowerCase();
    for (final p in {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    }.entries) {
      out = out.replaceAll(p.key, p.value);
    }
    return out;
  }

  void move(int value) {
    setState(() {
      index = value;
      step = 0;
      search.clear();
      createFolder = false;
    });
  }

  Future<void> dictate() async {
    await runAction(context, () async {
      if (voice) {
        await ref.read(speechPort).stop();
        if (mounted) setState(() => voice = false);
        return;
      }
      final ok = await ref.read(speechPort).listen((text) {
        if (mounted) setState(() => search.text = text);
      });
      if (mounted) setState(() => voice = ok);
    });
  }

  Future<void> next() async {
    if (voice) {
      await ref.read(speechPort).stop();
      voice = false;
    }
    if (!mounted) return;
    if (step == 0 &&
            current.folderId == null &&
            current.folderName.trim().isEmpty ||
        step == 1 &&
            current.noteId == null &&
            current.noteTitle.trim().isEmpty) {
      message(
        context,
        tr(context, 'Escribe la carpeta y el título del apunte.'),
      );
      return;
    }
    if (step < 2) {
      setState(() {
        step++;
        search.clear();
      });
      return;
    }
    reviewed.add(index);
    if (reviewed.length < drafts.length && index == drafts.length - 1) {
      move(
        List.generate(
          drafts.length,
          (i) => i,
        ).firstWhere((i) => !reviewed.contains(i)),
      );
      return;
    }
    if (index < drafts.length - 1) {
      move(index + 1);
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onComplete(drafts);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget row(
    String title,
    String subtitle,
    bool selected,
    IconData icon,
    VoidCallback tap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.surfaceContainerHigh
          : Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.outline
              : Theme.of(context).dividerColor,
        ),
      ),
      child: ListTile(
        onTap: busy ? null : tap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10),
        ),
        trailing: Icon(
          selected ? Icons.check : Icons.circle,
          size: selected ? 18 : 5,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value ?? const Library([], [], []);
    final d = current, query = norm(search.text);
    final folders = lib.folders
        .where((f) => norm(f.name).contains(query))
        .toList();
    final notes = lib.active
        .where(
          (n) =>
              n.folderId == d.folderId &&
              norm(n.title + ' ' + n.topic).contains(query),
        )
        .toList();
    final folder =
        lib.folders.where((f) => f.id == d.folderId).firstOrNull?.name ??
        d.folderName;
    final note =
        lib.active.where((n) => n.id == d.noteId).firstOrNull?.title ??
        d.noteTitle;
    return PopScope(
      canPop: !busy && step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy && step > 0) setState(() => step--);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: busy
                ? null
                : () {
                    if (step > 0) {
                      setState(() => step--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Meta('DRAFTAI'),
              Text(
                tr(
                  context,
                  widget.reviewOnly
                      ? 'Editar destino'
                      : 'Hazlo tú · Categorizar',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: FilledButton(
              onPressed: busy ? null : next,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      tr(
                        context,
                        busy
                            ? 'Guardando…'
                            : step < 2
                            ? 'Continuar al paso ' + (step + 2).toString()
                            : index < drafts.length - 1
                            ? 'Siguiente fuente'
                            : widget.reviewOnly
                            ? 'Confirmar destino'
                            : 'Guardar lote',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: ResponsiveBody(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: LinearProgressIndicator(
                        value: (step + 1) / 3,
                        minHeight: 3,
                      ),
                    ),
                    const Spacer(),
                    Meta(
                      tr(context, 'PASO') +
                          ' ' +
                          (step + 1).toString() +
                          ' ' +
                          tr(context, 'DE') +
                          ' 3',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Surface(
                  radius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => previewPickedFile(context, d.file),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: SizedBox(
                            height: 175,
                            width: double.infinity,
                            child: d.file.mime.startsWith('image/')
                                ? Image.memory(
                                    d.file.bytes,
                                    fit: BoxFit.contain,
                                    cacheWidth: 900,
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        d.file.mime == 'application/pdf'
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.description_outlined,
                                        size: 44,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        d.file.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.description_outlined, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Meta(
                              drafts.length.toString() +
                                  ' ' +
                                  tr(context, 'fuentes en el lote'),
                            ),
                          ),
                          Meta(
                            (index + 1).toString() +
                                ' / ' +
                                drafts.length.toString(),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: index == 0 || busy
                                ? null
                                : () => move(index - 1),
                            icon: const Icon(Icons.chevron_left, size: 18),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: index == drafts.length - 1 || busy
                                ? null
                                : () => move(index + 1),
                            icon: const Icon(Icons.chevron_right, size: 18),
                          ),
                        ],
                      ),
                      Text(
                        tr(context, 'Toca la vista previa para ampliar'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Icon(
                      step == 0
                          ? Icons.folder_outlined
                          : Icons.description_outlined,
                      size: 20,
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        tr(
                          context,
                          step == 0
                              ? '¿Dónde va este apunte?'
                              : step == 1
                              ? 'Elige el apunte'
                              : 'Revisa el destino',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    step == 0
                        ? 'Asigna una carpeta para organizar tus apuntes.'
                        : step == 1
                        ? 'Elige un apunte existente o crea uno nuevo.'
                        : 'Confirma antes de guardar.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (step < 2) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 18),
                            hintText: tr(
                              context,
                              step == 0 ? 'Buscar carpeta' : 'Buscar apunte',
                            ),
                            suffixIcon: search.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () => setState(search.clear),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: dictate,
                        child: Icon(
                          voice ? Icons.stop : Icons.mic_none,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (step == 0) ...[
                  for (final f in folders)
                    row(
                      f.name,
                      lib.active
                              .where((n) => n.folderId == f.id)
                              .length
                              .toString() +
                          ' ' +
                          tr(context, 'apuntes') +
                          ' · ' +
                          lib.active
                              .where((n) => n.folderId == f.id)
                              .take(2)
                              .map((n) => n.title)
                              .join(', '),
                      d.folderId == f.id,
                      Icons.description_outlined,
                      () => setState(() {
                        d.folderId = f.id;
                        d.folderName = f.name;
                        d.noteId = null;
                        createFolder = false;
                      }),
                    ),
                  if (folders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(tr(context, 'Sin resultados')),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      createFolder = true;
                      d.folderId = null;
                      d.noteId = null;
                      d.folderName = '';
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr(context, 'Agregar nueva carpeta')),
                  ),
                  if (createFolder || d.folderId == null)
                    TextFormField(
                      key: ValueKey('folder-$index'),
                      initialValue: d.folderName,
                      onChanged: (v) => d.folderName = v,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Nombre de la carpeta'),
                      ),
                    ),
                ],
                if (step == 1) ...[
                  Pill(folder),
                  const SizedBox(height: 12),
                  for (final n in notes)
                    row(
                      n.title,
                      n.topic.isEmpty ? dateLabel(n.updatedAt) : n.topic,
                      d.noteId == n.id,
                      Icons.description_outlined,
                      () => setState(() {
                        d.noteId = n.id;
                        d.noteTitle = n.title;
                      }),
                    ),
                  if (notes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(tr(context, 'Sin resultados')),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => d.noteId = null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr(context, 'Crear un apunte nuevo')),
                  ),
                  if (d.noteId == null)
                    TextFormField(
                      key: ValueKey('title-$index'),
                      initialValue: d.noteTitle,
                      onChanged: (v) => d.noteTitle = v,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Título del apunte'),
                      ),
                    ),
                ],
                if (step == 2) ...[
                  row(
                    folder,
                    note,
                    true,
                    Icons.check,
                    () => setState(() => step = 0),
                  ),
                  if (d.proposal != null ||
                      d.file.mime.startsWith('text/')) ...[
                    TextFormField(
                      key: ValueKey('text-$index'),
                      initialValue: d.text,
                      onChanged: (v) => d.text = v,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 12000,
                      decoration: InputDecoration(
                        labelText: tr(
                          context,
                          'Texto leído · revisa y corrige',
                        ),
                      ),
                    ),
                    if (d.proposal != null)
                      TextFormField(
                        key: ValueKey('summary-$index'),
                        initialValue: d.summary,
                        onChanged: (v) => d.summary = v,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 3000,
                        decoration: InputDecoration(
                          labelText: tr(context, 'Resumen interno'),
                        ),
                      ),
                  ],
                  if (drafts.length > 1)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        for (final other in drafts.where((v) => !v.saved)) {
                          other.folderId = d.folderId;
                          other.folderName = d.folderName;
                          other.noteId = d.noteId;
                          other.noteTitle = d.noteTitle;
                        }
                      }),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: Text(
                        tr(context, 'Aplicar este destino a todo el lote'),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
