import '../../../core/presentation/action_panel.dart';
import '../../../core/presentation/user_avatar.dart';
import '../../../core/presentation/strings.dart';

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
import '../../ai/presentation/ai_pages.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int tab = 0;
  bool trashMode = false;
  final Set<String> selectedIds = <String>{};

  bool get selecting => selectedIds.isNotEmpty;

  void _toggleSelection(String id) => setState(() {
    if (!selectedIds.add(id)) selectedIds.remove(id);
  });

  void _clearSelection() => setState(selectedIds.clear);

  void _openSelectedAi(Library lib) {
    final selected = lib.active
        .where((note) => selectedIds.contains(note.id))
        .toList();
    if (selected.isEmpty) return;
    openPage(context, AiPage(initialNotes: selected));
  }

  Widget _selectionBar({required int count, required List<Widget> actions}) =>
      Surface(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, '$count seleccionados'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close, size: 17),
                  label: Text(tr(context, 'Cancelar')),
                ),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      );

  Future<void> _trashSelected(Library lib) async {
    final selected = lib.active
        .where((note) => selectedIds.contains(note.id))
        .toList();
    if (selected.isEmpty) return;
    await runAction(context, () async {
      for (final note in selected) {
        await ref.read(controllerProvider.notifier).trash(note);
      }
      if (mounted) _clearSelection();
    });
  }

  Future<void> _restoreSelected(Library lib) async {
    final selected = lib.trash
        .where((note) => selectedIds.contains(note.id))
        .toList();
    if (selected.isEmpty) return;
    await runAction(context, () async {
      for (final note in selected) {
        await ref.read(controllerProvider.notifier).restore(note);
      }
      if (mounted) _clearSelection();
    });
  }

  Future<void> _deleteSelected(Library lib) async {
    final selected = lib.trash
        .where((note) => selectedIds.contains(note.id))
        .toList();
    if (selected.isEmpty) return;
    if (!await confirm(
      context,
      'Eliminar definitivamente',
      'Se eliminarán ${selected.length} apuntes seleccionados y sus archivos. Esta acción no se puede deshacer.',
    )) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () async {
      for (final note in selected) {
        await ref.read(controllerProvider.notifier).remove(note);
      }
      if (mounted) _clearSelection();
    });
  }

  List<Widget> _quickActions(Library lib) => [
    FilledButton.tonalIcon(
      onPressed: () => _trashSelected(lib),
      icon: const Icon(Icons.delete_outline, size: 17),
      label: Text(tr(context, 'Enviar a papelera')),
    ),
    OutlinedButton.icon(
      onPressed: () => exportMenu(
        context,
        ref,
        lib.active.where((n) => selectedIds.contains(n.id)).toList(),
      ),
      icon: const Icon(Icons.ios_share_outlined, size: 17),
      label: Text(tr(context, 'Exportar')),
    ),
    OutlinedButton.icon(
      onPressed: () => _openSelectedAi(lib),
      icon: const Icon(Icons.auto_awesome_outlined, size: 17),
      label: Text(tr(context, 'Generar resumen')),
    ),
  ];
  Widget _noteMenu(Note note, {required bool inTrash}) => IconButton(
    tooltip: tr(context, 'Acciones del apunte'),
    icon: const Icon(Icons.more_vert, size: 20),
    onPressed: () async {
      final action = await showActionPanel<String>(
        context,
        title: note.title,
        caption: 'ACCIONES · APUNTE',
        actions: inTrash
            ? const [
                PanelAction(
                  'restore',
                  'Restaurar',
                  'Volver a tus apuntes',
                  Icons.restore,
                ),
                PanelAction(
                  'delete',
                  'Eliminar definitivamente',
                  'Borrar este apunte y sus archivos',
                  Icons.delete_forever_outlined,
                ),
              ]
            : const [
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
                PanelAction(
                  'search',
                  'Buscar',
                  'Encontrar texto clave',
                  Icons.search,
                ),
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
              ],
      );
      if (!mounted) return;
      final ctrl = ref.read(controllerProvider.notifier);
      if (action == 'edit') openPage(context, NotePage(note: note, edit: true));
      if (action == 'search') openPage(context, const SearchPage());
      if (action == 'export') await exportMenu(context, ref, [note]);
      if (action == 'ai') openPage(context, AiPage(initialNotes: [note]));
      if (action == 'restore')
        await runAction(context, () => ctrl.restore(note));
      if (action == 'trash') await runAction(context, () => ctrl.trash(note));
      if (action == 'delete' &&
          await confirm(
            context,
            'Eliminar definitivamente',
            'Se eliminará este apunte y sus archivos. Esta acción no se puede deshacer.',
          )) {
        if (mounted) await runAction(context, () => ctrl.remove(note));
      }
    },
  );
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: tab == 3
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Meta('DRAFTAI'),
                  Text(tr(context, 'Papelera')),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', width: 29, height: 29),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      tr(context, tab == 3 ? 'Papelera' : 'DraftAI'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        leading: tab == 3
            ? IconButton(
                onPressed: () => setState(() {
                  tab = 0;
                  selectedIds.clear();
                  trashMode = false;
                }),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [HeaderSearchActions(showSearch: tab != 3)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selecting && tab != 3 && library.value != null)
              _selectionBar(
                count: selectedIds.length,
                actions: _quickActions(library.value!),
              ),
            Expanded(
              child: library.when(
                data: (lib) => tab == 0
                    ? _home(lib)
                    : tab == 2
                    ? _all(lib)
                    : _trash(lib),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr(context, 'No se pudo abrir la biblioteca: $e'),
                    ),
                  ),
                ),
                loading: () => Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
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
      onTap: () {
        if (index == 1) {
          newNoteMenu(context, ref);
        } else {
          setState(() {
            tab = index;
            selectedIds.clear();
          });
        }
      },
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
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 5),
            Text(
              tr(context, name),
              style: TextStyle(
                fontSize: 10,
                color: tab == index
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _home(Library lib) {
    final recent = NoteFilter.apply(lib.active).take(8).toList();
    final scaler = MediaQuery.textScalerOf(context);
    return ResponsiveBody(
      child: ListView(
        children: [
          SectionTitle(
            'Recientes',
            action: TextButton(
              onPressed: () => setState(() => tab = 2),
              child: Text(
                tr(context, 'Ver todos'),
                style: TextStyle(fontSize: 11),
              ),
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
              height: scaler.scale(148).clamp(148.0, 220.0).toDouble(),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => SizedBox(width: 11),
                itemBuilder: (c, i) => SizedBox(
                  width: scaler.scale(144).clamp(144.0, 190.0).toDouble(),
                  child: InkWell(
                    onTap: () => selecting
                        ? _toggleSelection(recent[i].id)
                        : openPage(context, NotePage(note: recent[i])),
                    onLongPress: () => _toggleSelection(recent[i].id),
                    child: Surface(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: RecentNotePreview(note: recent[i])),
                          SizedBox(height: 8),
                          Text(
                            recent[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Meta(dateLabel(recent[i].updatedAt)),
                              ),
                              if (selecting)
                                Icon(
                                  selectedIds.contains(recent[i].id)
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 19,
                                )
                              else
                                SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: _noteMenu(recent[i], inTrash: false),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('new-note'),
            onPressed: () => createNote(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(context, 'Nueva nota')),
          ),
          SectionTitle(
            'Tus carpetas',
            action: TextButton.icon(
              onPressed: () => editFolder(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              label: Text(
                tr(context, 'Nueva carpeta'),
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
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => runAction(
                context,
                () => ref.read(controllerProvider.notifier).loadExamples(),
              ),
              icon: const Icon(Icons.auto_stories_outlined, size: 18),
              label: Text(tr(context, 'Cargar biblioteca de ejemplo')),
            ),
          ],
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _folder(Folder f, Library lib) {
    final notes = lib.active.where((n) => n.folderId == f.id).toList();
    return Surface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: PageStorageKey('folder-${f.id}'),
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: FolderGlyph(f.color),
        title: Text(
          f.name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: Meta('${notes.length} ${tr(context, 'apuntes')}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: tr(context, 'Renombrar carpeta'),
              onPressed: () => editFolder(context, ref, folder: f),
              icon: const Icon(Icons.edit_outlined, size: 16),
            ),
            InkWell(
              onTap: () => editFolder(context, ref, folder: f, colorOnly: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _folderHex(f.color),
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
            ),
          ],
        ),
        children: [
          for (final n in notes.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onLongPress: () => _toggleSelection(n.id),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => selecting
                            ? _toggleSelection(n.id)
                            : openPage(context, NotePage(note: n)),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        icon: Icon(
                          selecting
                              ? (selectedIds.contains(n.id)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank)
                              : Icons.description_outlined,
                          size: 16,
                        ),
                        label: Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    if (!selecting) _noteMenu(n, inTrash: false),
                  ],
                ),
              ),
            ),
          if (notes.length > 6)
            TextButton(
              onPressed: () => openPage(context, SearchPage(folderId: f.id)),
              child: Text(tr(context, 'Ver ${notes.length} apuntes')),
            ),
          OutlinedButton.icon(
            onPressed: () => createNote(context, ref, folderId: f.id),
            icon: const Icon(Icons.add, size: 16),
            label: Text(tr(context, 'Agregar apunte')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _all(Library lib) => ResponsiveBody(
    child: ListView(
      children: [
        SectionTitle('Tus apuntes'),
        if (selecting)
          _selectionBar(count: selectedIds.length, actions: _quickActions(lib))
        else if (lib.active.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Meta(
              tr(context, 'Mantén pulsado un apunte para seleccionar varios.'),
            ),
          ),
        if (lib.active.isEmpty)
          _empty(
            'Sin apuntes todavía',
            'Usa + Nuevo para comenzar.',
            Icons.notes_outlined,
          ),
        ...NoteFilter.apply(lib.active).map(
          (n) => NoteTile(
            note: n,
            selected: selectedIds.contains(n.id),
            onTap: () => selecting
                ? _toggleSelection(n.id)
                : openPage(context, NotePage(note: n)),
            onLongPress: () => _toggleSelection(n.id),
            trailing: selecting ? null : _noteMenu(n, inTrash: false),
          ),
        ),
        SizedBox(height: 24),
      ],
    ),
  );
  Widget _trash(Library lib) => ResponsiveBody(
    child: ListView(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: lib.trash.isEmpty
                  ? null
                  : () async {
                      if (!await confirm(
                        context,
                        'Vaciar papelera',
                        'Se eliminarán todos los apuntes de la papelera y sus archivos. Esta acción no se puede deshacer.',
                      ))
                        return;
                      if (!mounted) return;
                      await runAction(context, () async {
                        for (final n in lib.trash) {
                          await ref.read(controllerProvider.notifier).remove(n);
                        }
                        if (mounted) _clearSelection();
                      });
                    },
              icon: const Icon(Icons.delete_outline, size: 17),
              label: Text(tr(context, 'Vaciar')),
            ),
            OutlinedButton.icon(
              onPressed: lib.trash.isEmpty
                  ? null
                  : () => setState(() {
                      trashMode = !trashMode;
                      if (!trashMode) selectedIds.clear();
                    }),
              icon: const Icon(Icons.check, size: 17),
              label: Text(tr(context, trashMode ? 'Cancelar' : 'Seleccionar')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Surface(
          radius: 16,
          child: Text(
            tr(
              context,
              'Los apuntes permanecen aquí hasta que los restaures o elimines definitivamente.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 14),
        if (selecting)
          _selectionBar(
            count: selectedIds.length,
            actions: [
              OutlinedButton.icon(
                onPressed: () => _restoreSelected(lib),
                icon: const Icon(Icons.restore, size: 17),
                label: Text(tr(context, 'Restaurar')),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _deleteSelected(lib),
                icon: const Icon(Icons.delete_forever_outlined, size: 17),
                label: Text(tr(context, 'Eliminar definitivamente')),
              ),
            ],
          ),
        if (lib.trash.isEmpty)
          _empty(
            'Tu papelera está vacía',
            'Los apuntes eliminados aparecerán aquí.',
            Icons.delete_outline,
          ),
        LayoutBuilder(
          builder: (c, box) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lib.trash.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: box.maxWidth < 300
                  ? 1
                  : box.maxWidth >= 900
                  ? 4
                  : box.maxWidth >= 600
                  ? 3
                  : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 16,
              mainAxisExtent: (190 * MediaQuery.textScalerOf(c).scale(1)).clamp(
                190.0,
                300.0,
              ),
            ),
            itemBuilder: (c, i) {
              final n = lib.trash[i],
                  age = DateTime.now()
                      .difference(n.deletedAt!)
                      .inDays
                      .clamp(0, 9999);
              return GestureDetector(
                onLongPress: () => setState(() {
                  trashMode = true;
                  _toggleSelection(n.id);
                }),
                onTap: () => setState(() {
                  trashMode = true;
                  _toggleSelection(n.id);
                }),
                child: Surface(
                  radius: 18,
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(c).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              trashMode
                                  ? (selectedIds.contains(n.id)
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank)
                                  : Icons.description_outlined,
                              size: 17,
                            ),
                          ),
                          const Spacer(),
                          Pill('$age d'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        n.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n.plainText.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(c).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Meta(
                              tr(c, 'Hace') + ' $age ' + tr(c, 'días'),
                            ),
                          ),
                          IconButton(
                            tooltip: tr(c, 'Eliminar definitivamente'),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              if (!await confirm(
                                context,
                                'Eliminar definitivamente',
                                'Se eliminará este apunte y sus archivos. Esta acción no se puede deshacer.',
                              ))
                                return;
                              if (mounted)
                                await runAction(
                                  context,
                                  () => ref
                                      .read(controllerProvider.notifier)
                                      .remove(n),
                                );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
  Widget _empty(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 26),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.muted),
        SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}

class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final String? subtitle;
  final bool selected;
  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.subtitle,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Surface(
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.description_outlined,
              size: 20,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Meta(
                    subtitle ??
                        '${note.topic.isEmpty ? 'Sin tema' : note.topic} · ${dateLabel(note.updatedAt)}',
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(selected ? Icons.check : Icons.chevron_right, size: 18),
          ],
        ),
      ),
    ),
  );
}

class RecentNotePreview extends ConsumerWidget {
  final Note note;
  const RecentNotePreview({super.key, required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = note.attachments
        .where((attachment) => attachment.mime.startsWith('image/'))
        .firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final preview = image == null
        ? Container(
            width: double.infinity,
            height: double.infinity,
            color: scheme.surfaceContainerLow,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(10),
            child: note.plainText.trim().isNotEmpty
                ? Text(
                    note.plainText.trim(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : note.attachments.isNotEmpty
                ? Row(
                    children: [
                      const Icon(Icons.attach_file, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tr(context, 'Archivo adjunto'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  )
                : Text(
                    tr(context, 'Sin contenido todavía'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          )
        : FutureBuilder(
            future: ref.read(mediaPort).read(image),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  color: scheme.surfaceContainerLow,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                );
              }
              if (!snapshot.hasData) {
                return Container(
                  color: scheme.surfaceContainerLow,
                  alignment: Alignment.center,
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: scheme.surfaceContainerLow,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              );
            },
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(7),
        ),
        child: SizedBox.expand(child: preview),
      ),
    );
  }
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
    var folders = library.folders;
    if (folders.isEmpty) {
      final folder = Folder(controller.newId(), 'Mis apuntes', 0xFFFFFFFF);
      await controller.folder(folder);
      folders = [folder];
      folderId = folder.id;
    }
    final initialFolder = folders.any((folder) => folder.id == folderId)
        ? folderId!
        : folders.first.id;
    final title = TextEditingController();
    String? selectedFolder = initialFolder;
    if (!context.mounted) return;
    final result = await showDialog<_NoteFormResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(tr(context, 'Nuevo apunte')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 200,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Título del apunte'),
                      helperText: tr(
                        context,
                        'Un nombre claro ayuda a la IA a elegir este apunte.',
                      ),
                      hintText: tr(context, 'Ej. Cálculo diferencial'),
                    ),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('note-folder-$selectedFolder'),
                    initialValue: selectedFolder,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Carpeta'),
                    ),
                    items: [
                      for (final folder in folders)
                        DropdownMenuItem(
                          value: folder.id,
                          child: Row(
                            children: [
                              FolderGlyph(folder.color),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      selectedFolder = value;
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr(context, 'Cancelar')),
              ),
              FilledButton.icon(
                onPressed: selectedFolder == null
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _NoteFormResult(
                          folderId: selectedFolder!,
                          categoryId: null,
                          title: title.text.trim(),
                        ),
                      ),
                icon: const Icon(Icons.add, size: 17),
                label: Text(tr(context, 'Crear apunte')),
              ),
            ],
          );
        },
      ),
    );
    title.dispose();
    if (result == null || !context.mounted) return;
    if (!context.mounted) return;
    final note = await controller.create(
      result.folderId,
      title: result.title,
      categoryId: result.categoryId,
    );
    if (context.mounted) openPage(context, NotePage(note: note, edit: true));
  });
}

class _NoteFormResult {
  final String folderId;
  final String title;
  final String? categoryId;
  const _NoteFormResult({
    required this.folderId,
    required this.title,
    required this.categoryId,
  });
}

Future<void> newNoteMenu(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(tr(context, 'Añadir a tus apuntes'))),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(tr(context, 'Escribir nota')),
            onTap: () {
              Navigator.pop(c);
              createNote(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(tr(context, 'Capturar fotografías')),
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
            title: Text(tr(context, 'Añadir imágenes')),
            onTap: () {
              Navigator.pop(c);
              openPage(context, const CapturePage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(tr(context, 'Agregar archivos o texto')),
            onTap: () {
              Navigator.pop(c);
              openPage(context, const CapturePage(source: CaptureSource.files));
            },
          ),
          SizedBox(height: 12),
        ],
      ),
    ),
  );
}

String _folderHex(int argb) =>
    '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

int? _parseFolderHex(String value) {
  final hex = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex, radix: 16);
}

Color _folderForeground(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.light
    ? const Color(0xFF191919)
    : Colors.white;

Future<void> editFolder(
  BuildContext context,
  WidgetRef ref, {
  Folder? folder,
  bool colorOnly = false,
}) async {
  final name = TextEditingController(text: folder?.name ?? '');
  var color = folder?.color ?? 0xFFFFFFFF;
  final original = color;
  final hex = TextEditingController(text: _folderHex(color));
  final result = await showDialog<Folder>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) => AlertDialog(
        title: Text(
          tr(
            dialog,
            colorOnly
                ? 'Color de carpeta'
                : folder == null
                ? 'Nueva carpeta'
                : 'Renombrar carpeta',
          ),
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!colorOnly)
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 80,
                    onChanged: (_) => set(() {}),
                    decoration: InputDecoration(
                      labelText: tr(dialog, 'Nombre de la carpeta'),
                    ),
                  ),
                if (colorOnly) ...[
                  Row(
                    children: [
                      FolderGlyph(color, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          folder!.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 140,
                    child: _ColorSpectrum(
                      color: Color(color),
                      onChanged: (next) => set(() {
                        color = next.toARGB32();
                        hex.text = _folderHex(color);
                      }),
                    ),
                  ),
                  Slider(
                    value: HSVColor.fromColor(Color(color)).hue,
                    min: 0,
                    max: 360,
                    onChanged: (hue) => set(() {
                      final hsv = HSVColor.fromColor(Color(color));
                      color = HSVColor.fromAHSV(
                        1,
                        hue,
                        hsv.saturation < .1 ? .65 : hsv.saturation,
                        hsv.value < .1 ? .85 : hsv.value,
                      ).toColor().toARGB32();
                      hex.text = _folderHex(color);
                    }),
                  ),
                  TextField(
                    controller: hex,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      hintText: '#FFFFFF',
                    ),
                    onChanged: (value) {
                      final parsed = _parseFolderHex(value);
                      if (parsed != null) set(() => color = parsed);
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in [
                        0xFFFFFFFF,
                        0xFF9E9E9E,
                        0xFF333333,
                        0xFF84B6E8,
                        0xFFA9CDA4,
                        0xFFD6B0DC,
                        0xFFE0B78B,
                        0xFFE7D28D,
                      ])
                        InkWell(
                          onTap: () => set(() {
                            color = value;
                            hex.text = _folderHex(value);
                          }),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(dialog).colorScheme.outline,
                                width: color == value ? 2 : 1,
                              ),
                            ),
                            child: color == value
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: _folderForeground(Color(value)),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => set(() {
                      color = original;
                      hex.text = _folderHex(color);
                    }),
                    child: Text(tr(dialog, 'Restaurar original')),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (folder != null && !colorOnly)
            TextButton(
              onPressed: () async {
                final library = ref.read(libraryProvider).value;
                if (library?.notes.any((n) => n.folderId == folder.id) ??
                    false) {
                  message(
                    dialog,
                    tr(
                      dialog,
                      'Mueve los apuntes o elimínalos definitivamente de la papelera antes de borrar la carpeta.',
                    ),
                  );
                  return;
                }
                if (!await confirm(
                  dialog,
                  'Eliminar carpeta',
                  'Esta acción no se puede deshacer.',
                )) {
                  return;
                }
                if (!dialog.mounted) return;
                Navigator.pop(dialog);
                if (context.mounted) {
                  await runAction(
                    context,
                    () => ref
                        .read(controllerProvider.notifier)
                        .deleteFolder(folder.id),
                  );
                }
              },
              child: Text(
                tr(dialog, 'Eliminar'),
                style: TextStyle(color: Theme.of(dialog).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(tr(dialog, 'Cancelar')),
          ),
          FilledButton(
            onPressed:
                name.text.trim().isEmpty || _parseFolderHex(hex.text) == null
                ? null
                : () => Navigator.pop(
                    dialog,
                    Folder(
                      folder?.id ??
                          ref.read(controllerProvider.notifier).newId(),
                      name.text.trim(),
                      color,
                    ),
                  ),
            child: Text(tr(dialog, colorOnly ? 'Aplicar' : 'Guardar')),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  hex.dispose();
  if (result != null && context.mounted) {
    await runAction(
      context,
      () => ref.read(controllerProvider.notifier).folder(result),
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const Meta('DRAFTAI'), Text(tr(context, 'Buscar'))],
        ),
        actions: const [HeaderSearchActions(showSearch: false)],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          child: ListView(
            children: [
              SizedBox(height: 16),
              TextField(
                key: const Key('search-field'),
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: tr(context, 'Buscar en tus apuntes'),
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
              SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    for (final value in ['Todo', 'Título', 'Tema'])
                      Expanded(
                        child: Material(
                          color: mode == value
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            onTap: () => setState(() => mode = value),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Text(
                                tr(context, value),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: mode == value
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (listening)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    tr(
                      context,
                      'Escuchando… Puedes detener el micrófono cuando termines.',
                    ),
                  ),
                ),
              SectionTitle(
                search.text.isEmpty
                    ? 'Apuntes recientes'
                    : '${results.length} resultados',
              ),
              if (results.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    tr(
                      context,
                      'No se encontraron apuntes. Prueba otra palabra.',
                    ),
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

class _ColorSpectrum extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;
  const _ColorSpectrum({required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final hsv = HSVColor.fromColor(color);
      void choose(Offset point) {
        onChanged(
          HSVColor.fromAHSV(
            1,
            hsv.hue,
            (point.dx / box.maxWidth).clamp(0, 1),
            (1 - point.dy / box.maxHeight).clamp(0, 1),
          ).toColor(),
        );
      }

      return Semantics(
        label: Localizations.localeOf(context).languageCode == 'en'
            ? 'Color spectrum'
            : 'Espectro de color',
        child: GestureDetector(
          onPanDown: (d) => choose(d.localPosition),
          onPanUpdate: (d) => choose(d.localPosition),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                    ],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              Positioned(
                left: (hsv.saturation * box.maxWidth - 6).clamp(
                  0,
                  box.maxWidth - 12,
                ),
                top: ((1 - hsv.value) * box.maxHeight - 6).clamp(
                  0,
                  box.maxHeight - 12,
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class HeaderSearchActions extends StatelessWidget {
  final bool showSearch;
  const HeaderSearchActions({super.key, this.showSearch = true});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showSearch)
        Container(
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tr(context, 'Buscar'),
                onPressed: () => openPage(context, const SearchPage()),
                icon: const Icon(Icons.search, size: 18),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tr(context, 'Búsqueda por voz'),
                onPressed: () =>
                    openPage(context, const SearchPage(voice: true)),
                icon: const Icon(Icons.mic_none, size: 18),
              ),
            ],
          ),
        ),
      IconButton(
        tooltip: tr(context, 'Abrir perfil'),
        onPressed: () => openPage(context, const ProfilePage()),
        icon: const UserAvatar(),
      ),
      const SizedBox(width: 4),
    ],
  );
}
