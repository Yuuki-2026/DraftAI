import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import '../domain/ports.dart';
import 'controller.dart';
import 'note_page.dart';
import '../../capture/presentation/capture_page.dart';
import '../../settings/presentation/settings_pages.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 29, height: 29),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'DraftAI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => openPage(context, const SearchPage()),
            icon: const Icon(Icons.search, size: 21),
          ),
          IconButton(
            tooltip: 'Búsqueda por voz',
            onPressed: () => openPage(context, const SearchPage(voice: true)),
            icon: const Icon(Icons.mic_none, size: 21),
          ),
          IconButton(
            tooltip: 'Abrir perfil',
            onPressed: () => openPage(context, const ProfilePage()),
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.mid,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/12225881.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: SafeArea(
        top: false,
        child: library.when(
          data: (lib) => tab == 0
              ? _home(lib)
              : tab == 2
              ? _all(lib)
              : _trash(lib),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudo abrir la biblioteca: $e'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
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
          child: Row(
            children: [
              _nav(Icons.home_outlined, 'Inicio', 0),
              _nav(Icons.add_circle_outline, '+ Nuevo', 1),
              _nav(Icons.format_list_bulleted, 'Apuntes', 2),
              _nav(Icons.delete_outline, 'Papelera', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(IconData icon, String name, int index) => Expanded(
    child: InkWell(
      onTap: () =>
          index == 1 ? newNoteMenu(context, ref) : setState(() => tab = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: tab == index
                  ? Theme.of(context).colorScheme.onSurface
                  : AppColors.muted,
            ),
            const SizedBox(height: 5),
            Text(
              name,
              style: TextStyle(
                fontSize: 10,
                color: tab == index
                    ? Theme.of(context).colorScheme.onSurface
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _home(Library lib) {
    final recent = NoteFilter.apply(lib.active).take(8).toList();
    return ResponsiveBody(
      child: ListView(
        children: [
          SectionTitle(
            'Recientes',
            action: TextButton(
              onPressed: () => setState(() => tab = 2),
              child: const Text('Ver todos', style: TextStyle(fontSize: 11)),
            ),
          ),
          if (recent.isEmpty)
            _empty(
              'Tus ideas empiezan aquí',
              'Crea tu primer apunte o añade imágenes.',
              Icons.edit_note,
            )
          else
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(128),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (c, i) => SizedBox(
                  width: 128,
                  child: InkWell(
                    onTap: () => openPage(context, NotePage(note: recent[i])),
                    child: Surface(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 62,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.mid,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final width in [85.0, 65.0, 43.0])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Container(
                                      width: width,
                                      height: 3,
                                      color: AppColors.line,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            recent[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Meta(dateLabel(recent[i].updatedAt)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('new-note'),
            onPressed: () => createNote(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva nota'),
          ),
          SectionTitle(
            'Tus carpetas',
            action: TextButton.icon(
              onPressed: () => editFolder(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              label: const Text(
                'Nueva carpeta',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (c, box) {
              final columns = Breakpoints.columns(box.maxWidth);
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: lib.folders
                    .map(
                      (folder) => SizedBox(
                        width: (box.maxWidth - (columns - 1) * 14) / columns,
                        child: _folder(folder, lib),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (lib.folders.isEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => runAction(
                context,
                () => ref.read(controllerProvider.notifier).loadExamples(),
              ),
              icon: const Icon(Icons.auto_stories_outlined, size: 18),
              label: const Text('Cargar ejemplos del mockup'),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _folder(Folder f, Library lib) {
    final notes = lib.active.where((n) => n.folderId == f.id).toList();
    return Surface(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, color: Color(f.color), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  f.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Editar carpeta',
                onPressed: () => editFolder(context, ref, folder: f),
                icon: const Icon(Icons.edit_outlined, size: 17),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de carpeta',
                onSelected: (v) => v == 'category'
                    ? editCategory(context, ref, f)
                    : runAction(context, () async {
                        if (await confirm(
                          context,
                          'Eliminar carpeta',
                          'Solo se puede eliminar una carpeta vacía.',
                        )) {
                          await ref
                              .read(controllerProvider.notifier)
                              .deleteFolder(f.id);
                        }
                      }),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'category',
                    child: Text('Nueva categoría'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar carpeta'),
                  ),
                ],
              ),
            ],
          ),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Meta('Aún no hay apuntes en esta carpeta.'),
            ),
          for (final n in notes.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => openPage(context, NotePage(note: n)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (notes.length > 6)
            TextButton(
              onPressed: () => openPage(context, SearchPage(folderId: f.id)),
              child: Text('Ver ${notes.length} apuntes'),
            ),
          OutlinedButton.icon(
            onPressed: () => createNote(context, ref, folderId: f.id),
            icon: const Icon(Icons.add, size: 15),
            label: const Text('Agregar apunte', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _all(Library lib) => ResponsiveBody(
    child: ListView(
      children: [
        const SectionTitle('Tus apuntes'),
        if (lib.active.isEmpty)
          _empty(
            'Sin apuntes todavía',
            'Usa + Nuevo para comenzar.',
            Icons.notes_outlined,
          ),
        ...NoteFilter.apply(lib.active).map(
          (n) => NoteTile(
            note: n,
            onTap: () => openPage(context, NotePage(note: n)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
  Widget _trash(Library lib) => ResponsiveBody(
    child: ListView(
      children: [
        SectionTitle(
          'Papelera',
          action: lib.trash.isEmpty
              ? null
              : TextButton(
                  onPressed: () => runAction(context, () async {
                    if (await confirm(
                      context,
                      'Vaciar papelera',
                      'Se eliminarán definitivamente ${lib.trash.length} apuntes y sus imágenes. Esta acción no se puede deshacer.',
                    )) {
                      for (final n in lib.trash) {
                        await ref.read(controllerProvider.notifier).remove(n);
                      }
                    }
                  }),
                  child: const Text('Vaciar'),
                ),
        ),
        if (lib.trash.isEmpty)
          _empty(
            'Tu papelera está vacía',
            'Los apuntes eliminados aparecerán aquí.',
            Icons.delete_outline,
          ),
        for (final n in lib.trash)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: Theme.of(context).textTheme.titleMedium),
                  Meta('Eliminado: ${dateLabel(n.deletedAt!)}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => runAction(
                          context,
                          () =>
                              ref.read(controllerProvider.notifier).restore(n),
                        ),
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Restaurar'),
                      ),
                      TextButton(
                        onPressed: () => runAction(context, () async {
                          if (await confirm(
                            context,
                            'Eliminar definitivamente',
                            'Se eliminará este apunte y sus imágenes.',
                          )) {
                            await ref
                                .read(controllerProvider.notifier)
                                .remove(n);
                          }
                        }),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  Widget _empty(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 26),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}

class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const NoteTile({super.key, required this.note, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      child: Surface(
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 20,
              color: AppColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Meta(
                    '${note.topic.isEmpty ? 'Sin tema' : note.topic} · ${dateLabel(note.updatedAt)}',
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    ),
  );
}

Future<void> createNote(
  BuildContext context,
  WidgetRef ref, {
  String? folderId,
}) async {
  await runAction(context, () async {
    final library = ref.read(libraryProvider).value;
    if (library == null) return;
    final controller = ref.read(controllerProvider.notifier);
    if (folderId == null) {
      if (library.folders.isEmpty) {
        final f = Folder(controller.newId(), 'Mis apuntes', 0xFFFFFFFF);
        await controller.folder(f);
        folderId = f.id;
      } else if (library.folders.length == 1) {
        folderId = library.folders.first.id;
      } else {
        folderId = await showModalBottomSheet<String>(
          context: context,
          builder: (c) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('¿Dónde guardar la nota?')),
                ...library.folders.map(
                  (f) => ListTile(
                    leading: Icon(Icons.folder_outlined, color: Color(f.color)),
                    title: Text(f.name),
                    onTap: () => Navigator.pop(c, f.id),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (folderId == null) return;
    final note = await controller.create(folderId!);
    if (context.mounted) openPage(context, NotePage(note: note, edit: true));
  });
}

Future<void> newNoteMenu(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Añadir a tus apuntes')),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Escribir nota'),
            onTap: () {
              Navigator.pop(c);
              createNote(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Capturar fotografías'),
            onTap: () {
              Navigator.pop(c);
              openPage(
                context,
                const CapturePage(source: CaptureSource.camera),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Añadir imágenes'),
            onTap: () {
              Navigator.pop(c);
              openPage(context, const CapturePage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Agregar archivos o texto'),
            onTap: () {
              Navigator.pop(c);
              openPage(context, const CapturePage(source: CaptureSource.files));
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

Future<void> editFolder(
  BuildContext context,
  WidgetRef ref, {
  Folder? folder,
}) async {
  final name = TextEditingController(text: folder?.name);
  int color = folder?.color ?? 0xFFFFFFFF;
  final result = await showDialog<Folder>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(folder == null ? 'Nueva carpeta' : 'Editar carpeta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 80,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la carpeta',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Color de carpeta'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final value in [
                    0xFFFFFFFF,
                    0xFF9E9E9E,
                    0xFFE5A5A5,
                    0xFFE5CCA5,
                    0xFFA5C5E5,
                    0xFFB7D7B0,
                    0xFFC5AFE0,
                    0xFFA5DAD5,
                  ])
                    Semantics(
                      label: 'Color ${value.toRadixString(16)}',
                      selected: color == value,
                      button: true,
                      child: InkWell(
                        onTap: () => set(() => color = value),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: color == value ? 3 : 1,
                              color: color == value
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                          child: color == value
                              ? const Icon(
                                  Icons.check,
                                  size: 19,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(
                  c,
                  Folder(
                    folder?.id ?? ref.read(controllerProvider.notifier).newId(),
                    name.text.trim(),
                    color,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  if (result != null && context.mounted) {
    await runAction(
      context,
      () => ref.read(controllerProvider.notifier).folder(result),
    );
  }
}

Future<void> editCategory(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final name = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Nueva categoría'),
      content: TextField(
        controller: name,
        maxLength: 80,
        decoration: InputDecoration(labelText: 'Categoría en ${folder.name}'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, name.text.trim()),
          child: const Text('Crear'),
        ),
      ],
    ),
  );
  name.dispose();
  if (result != null && result.isNotEmpty && context.mounted) {
    await runAction(
      context,
      () => ref
          .read(controllerProvider.notifier)
          .category(
            Category(
              ref.read(controllerProvider.notifier).newId(),
              folder.id,
              result,
            ),
          ),
    );
  }
}

class SearchPage extends ConsumerStatefulWidget {
  final bool voice;
  final String? folderId;
  const SearchPage({super.key, this.voice = false, this.folderId});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final search = TextEditingController();
  late final SpeechService speech;
  String mode = 'Todo';
  bool listening = false;
  @override
  void initState() {
    super.initState();
    speech = ref.read(speechPort);
    if (widget.voice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _voice());
    }
  }

  Future<void> _voice() async {
    await runAction(context, () async {
      if (listening) {
        await speech.stop();
        if (mounted) setState(() => listening = false);
        return;
      }
      final available = await speech.listen((text) {
        if (mounted) setState(() => search.text = text);
      });
      if (!mounted) return;
      setState(() => listening = available);
      if (!available) {
        message(
          context,
          'El reconocimiento de voz no está disponible. Revisa el permiso de micrófono o escribe tu consulta.',
        );
      }
    });
  }

  @override
  void dispose() {
    speech.stop();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value;
    final results = NoteFilter.apply(
      lib?.active ?? [],
      query: search.text,
      mode: mode,
      folderId: widget.folderId,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar apuntes')),
      body: SafeArea(
        child: ResponsiveBody(
          child: ListView(
            children: [
              const SizedBox(height: 16),
              TextField(
                key: const Key('search-field'),
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar en tus apuntes',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: listening ? 'Detener voz' : 'Buscar por voz',
                    onPressed: _voice,
                    icon: Icon(
                      listening ? Icons.stop_circle_outlined : Icons.mic_none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['Todo', 'Título', 'Tema']
                    .map(
                      (s) => ChoiceChip(
                        label: Text(s),
                        selected: mode == s,
                        onSelected: (_) => setState(() => mode = s),
                      ),
                    )
                    .toList(),
              ),
              if (listening)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Escuchando… Puedes detener el micrófono cuando termines.',
                  ),
                ),
              SectionTitle(
                search.text.isEmpty
                    ? 'Apuntes recientes'
                    : '${results.length} resultados',
              ),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No se encontraron apuntes. Prueba otra palabra.',
                  ),
                ),
              ...results.map(
                (n) => NoteTile(
                  note: n,
                  onTap: () => openPage(context, NotePage(note: n)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
