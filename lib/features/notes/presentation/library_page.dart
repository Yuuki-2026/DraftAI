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

  Widget _noteMenu(
    Note note, {
    required bool inTrash,
  }) => PopupMenuButton<String>(
    tooltip: tr(context, 'Acciones del apunte'),
    onSelected: (action) async {
      final controller = ref.read(controllerProvider.notifier);
      if (action == 'edit') {
        openPage(context, NotePage(note: note, edit: true));
      } else if (action == 'ai') {
        openPage(context, AiPage(initialNotes: [note]));
      } else if (action == 'restore') {
        await runAction(context, () => controller.restore(note));
      } else if (action == 'trash') {
        await runAction(context, () => controller.trash(note));
      } else if (action == 'delete' &&
          await confirm(
            context,
            'Eliminar definitivamente',
            'Se eliminará este apunte y sus archivos. Esta acción no se puede deshacer.',
          )) {
        if (!mounted) return;
        await runAction(context, () => controller.remove(note));
      }
    },
    itemBuilder: (context) => [
      if (!inTrash) ...[
        PopupMenuItem(value: 'edit', child: Text(tr(context, 'Editar apunte'))),
        PopupMenuItem(
          value: 'ai',
          child: Text(tr(context, 'Herramientas de IA')),
        ),
        PopupMenuItem(
          value: 'trash',
          child: Text(tr(context, 'Enviar a la papelera')),
        ),
      ] else ...[
        PopupMenuItem(value: 'restore', child: Text(tr(context, 'Restaurar'))),
        PopupMenuItem(
          value: 'delete',
          child: Text(tr(context, 'Eliminar definitivamente')),
        ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 29, height: 29),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                tr(context, 'DraftAI'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'Buscar'),
            onPressed: () => openPage(context, const SearchPage()),
            icon: const Icon(Icons.search, size: 21),
          ),
          IconButton(
            tooltip: tr(context, 'Búsqueda por voz'),
            onPressed: () => openPage(context, const SearchPage(voice: true)),
            icon: const Icon(Icons.mic_none, size: 21),
          ),
          IconButton(
            tooltip: tr(context, 'Abrir perfil'),
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
          SizedBox(width: 8),
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
              child: Text(tr(context, 'No se pudo abrir la biblioteca: $e')),
            ),
          ),
          loading: () => Center(child: CircularProgressIndicator()),
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
                  : AppColors.muted,
            ),
            SizedBox(height: 5),
            Text(
              tr(context, name),
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
              height: scaler.scale(180).clamp(180.0, 236.0).toDouble(),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => SizedBox(width: 11),
                itemBuilder: (c, i) => SizedBox(
                  width: 196,
                  child: InkWell(
                    onTap: () => openPage(context, NotePage(note: recent[i])),
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
                          Meta(dateLabel(recent[i].updatedAt)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: 12),
          FilledButton.icon(
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
              label: Text(tr(context, 'Cargar ejemplos del mockup')),
            ),
          ],
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _folder(Folder f, Library lib) {
    final notes = lib.active.where((n) => n.folderId == f.id).toList();
    final categories = lib.categories
        .where((category) => category.folderId == f.id)
        .toList();
    final folderColor = Color(f.color);
    final bright =
        ThemeData.estimateBrightnessForColor(folderColor) == Brightness.light;
    final foreground = bright ? const Color(0xFF1B1B1B) : Colors.white;
    final subtle = bright
        ? Colors.black.withValues(alpha: .07)
        : Colors.white.withValues(alpha: .12);
    final stackActions = MediaQuery.textScalerOf(context).scale(11) > 14;
    final categoryAction = OutlinedButton.icon(
      onPressed: () => editCategory(context, ref, f),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: .38)),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      icon: const Icon(Icons.sell_outlined, size: 15),
      label: Text(
        tr(context, 'Nueva categoría'),
        style: TextStyle(fontSize: 11),
      ),
    );
    final addNoteAction = FilledButton.tonalIcon(
      onPressed: () => createNote(context, ref, folderId: f.id),
      style: FilledButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: subtle,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      icon: const Icon(Icons.add, size: 15),
      label: Text(
        tr(context, 'Agregar apunte'),
        style: TextStyle(fontSize: 11),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: folderColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bright
              ? Theme.of(context).colorScheme.outline
              : Colors.white.withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.folder, color: foreground, size: 23),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  f.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ).copyWith(color: foreground),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Editar carpeta'),
                onPressed: () => editFolder(context, ref, folder: f),
                icon: Icon(Icons.edit_outlined, size: 17, color: foreground),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in categories)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: subtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: foreground.withValues(alpha: .16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sell_outlined, size: 13, color: foreground),
                        SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                tr(context, 'Aún no hay apuntes en esta carpeta.'),
                style: TextStyle(color: foreground),
              ),
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
                    color: subtle,
                    border: Border.all(
                      color: foreground.withValues(alpha: .16),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description, size: 16, color: foreground),
                      SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: foreground),
                            ),
                            if (n.categoryId != null)
                              Text(
                                '${tr(context, "Categoría")} · ${categories.where((category) => category.id == n.categoryId).firstOrNull?.name ?? tr(context, "Sin categoría")}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground.withValues(alpha: .78),
                                  fontSize: 10,
                                ),
                              ),
                          ],
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
              child: Text(
                tr(context, 'Ver ${notes.length} apuntes'),
                style: TextStyle(color: foreground),
              ),
            ),
          if (stackActions) ...[
            SizedBox(width: double.infinity, child: categoryAction),
            SizedBox(height: 8),
            SizedBox(width: double.infinity, child: addNoteAction),
          ] else
            Row(
              children: [
                Expanded(child: categoryAction),
                SizedBox(width: 8),
                Expanded(child: addNoteAction),
              ],
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
          _selectionBar(
            count: selectedIds.length,
            actions: [
              FilledButton.tonalIcon(
                onPressed: () => _trashSelected(lib),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: Text(tr(context, 'Enviar a papelera')),
              ),
              OutlinedButton.icon(
                onPressed: () => _openSelectedAi(lib),
                icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                label: Text(tr(context, 'Herramientas de IA')),
              ),
            ],
          )
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
        SectionTitle(
          'Papelera',
          action: lib.trash.isEmpty || selecting
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
                  child: Text(tr(context, 'Vaciar')),
                ),
        ),
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
          )
        else if (lib.trash.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Meta(
              tr(
                context,
                'Toca un apunte para seleccionarlo o mantenerlo pulsado para empezar.',
              ),
            ),
          ),
        if (lib.trash.isEmpty)
          _empty(
            'Tu papelera está vacía',
            'Los apuntes eliminados aparecerán aquí.',
            Icons.delete_outline,
          ),
        for (final n in lib.trash)
          NoteTile(
            note: n,
            selected: selectedIds.contains(n.id),
            subtitle: 'Eliminado: ${dateLabel(n.deletedAt!)}',
            onTap: () => _toggleSelection(n.id),
            onLongPress: () => _toggleSelection(n.id),
            trailing: selecting ? null : _noteMenu(n, inTrash: true),
          ),
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
                  : AppColors.muted,
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
    String? selectedCategory;
    if (!context.mounted) return;
    final result = await showDialog<_NoteFormResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final categories = library.categories
              .where((category) => category.folderId == selectedFolder)
              .toList();
          if (!categories.any((category) => category.id == selectedCategory)) {
            selectedCategory = null;
          }
          return AlertDialog(
            title: Text(tr(context, 'Añadir apunte')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr(context, 'Elige dónde guardar este apunte.')),
                  SizedBox(height: 14),
                  TextField(
                    controller: title,
                    maxLength: 200,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Título del apunte'),
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
                              Icon(
                                Icons.folder,
                                color: _folderForeground(Color(folder.color)),
                              ),
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
                      selectedCategory = null;
                    }),
                  ),
                  if (categories.isNotEmpty) ...[
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'note-category-$selectedFolder-$selectedCategory',
                      ),
                      initialValue: selectedCategory ?? '',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Categoría (opcional)'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(tr(context, 'Sin categoría')),
                        ),
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => selectedCategory = value == '' ? null : value,
                      ),
                    ),
                  ],
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
                          categoryId: selectedCategory,
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
}) async {
  final name = TextEditingController(text: folder?.name);
  final original = folder?.color ?? 0xFFFFFFFF;
  var color = original;
  final hex = TextEditingController(text: _folderHex(color));
  final palette = <int>[
    0xFFFFFFFF,
    0xFFF1F5F9,
    0xFFDCE8F1,
    0xFFB8D4EA,
    0xFFE9DDF7,
    0xFFECCFD8,
    0xFFF2D7B8,
    0xFFF0E6A9,
    0xFFD4E8BD,
    0xFFB9DDD7,
    0xFFDBE7C5,
    0xFFCBD6F0,
  ];
  final result = await showDialog<Folder>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final foreground = _folderForeground(Color(color));
        return AlertDialog(
          title: Text(folder == null ? 'Nueva carpeta' : 'Editar carpeta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  maxLength: 80,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: tr(context, 'Nombre de la carpeta'),
                  ),
                ),
                SizedBox(height: 14),
                SectionTitle('Previsualización'),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Color(color),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(dialogContext).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder, color: foreground),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name.text.trim().isEmpty
                              ? 'Nombre de carpeta'
                              : name.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionTitle('Tono'),
                Slider(
                  value: HSVColor.fromColor(Color(color)).hue
                      .clamp(0.0, 360.0)
                      .toDouble(),
                  min: 0,
                  max: 360,
                  divisions: 360,
                  label: '${HSVColor.fromColor(Color(color)).hue.round()}°',
                  onChanged: (hue) => setDialogState(() {
                    final hsv = HSVColor.fromColor(Color(color));
                    color = HSVColor.fromAHSV(
                      1,
                      hue,
                      hsv.saturation < .12 ? .7 : hsv.saturation,
                      hsv.value < .2 ? .92 : hsv.value,
                    ).toColor().toARGB32();
                    hex.text = _folderHex(color);
                  }),
                ),
                SizedBox(
                  height: 140,
                  child: _ColorSpectrum(
                    color: Color(color),
                    onChanged: (next) => setDialogState(() {
                      color = next.toARGB32();
                      hex.text = _folderHex(color);
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hex,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: tr(context, 'HEX'),
                    prefixIcon: Icon(Icons.tag),
                    hintText: tr(context, '#DCE8F1'),
                  ),
                  onChanged: (value) {
                    final parsed = _parseFolderHex(value);
                    if (parsed != null) setDialogState(() => color = parsed);
                  },
                ),
                SectionTitle('Colores recomendados'),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final value in palette)
                      Semantics(
                        label: 'Color ${_folderHex(value)}',
                        selected: color == value,
                        button: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setDialogState(() {
                            color = value;
                            hex.text = _folderHex(value);
                          }),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: color == value ? 2.5 : 1,
                                color: color == value
                                    ? Theme.of(dialogContext)
                                          .colorScheme
                                          .primary
                                    : Theme.of(dialogContext)
                                          .colorScheme
                                          .outline,
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
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setDialogState(() {
                      color = original;
                      hex.text = _folderHex(original);
                    }),
                    icon: const Icon(Icons.restart_alt, size: 17),
                    label: Text(tr(context, 'Restaurar original')),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (folder != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () async {
                  final library = ref.read(libraryProvider).value;
                  if (library?.notes.any(
                        (note) => note.folderId == folder.id,
                      ) ??
                      false) {
                    message(
                      context,
                      'Mueve o elimina los apuntes de esta carpeta primero.',
                    );
                    return;
                  }
                  if (!await confirm(
                    context,
                    'Eliminar carpeta',
                    'También se eliminarán sus categorías. Esta acción no se puede deshacer.',
                  )) {
                    return;
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await runAction(
                    context,
                    () => ref
                        .read(controllerProvider.notifier)
                        .deleteFolder(folder.id),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 17),
                label: Text(tr(context, 'Eliminar')),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr(context, 'Cancelar')),
            ),
            FilledButton.icon(
              onPressed:
                  name.text.trim().isEmpty || _parseFolderHex(hex.text) == null
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      Folder(
                        folder?.id ??
                            ref.read(controllerProvider.notifier).newId(),
                        name.text.trim(),
                        color,
                      ),
                    ),
              icon: const Icon(Icons.check, size: 17),
              label: Text(tr(context, 'Confirmar')),
            ),
          ],
        );
      },
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

Future<void> editCategory(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final name = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(tr(context, 'Nueva categoría')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  'La categoría organizará apuntes de ${folder.name}.',
                ),
              ),
              SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext)
                      .colorScheme
                      .surfaceContainerLow,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Theme.of(dialogContext).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: name,
                maxLength: 80,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  labelText: tr(context, 'Nombre de categoría'),
                  hintText: tr(context, 'Ej. Exámenes'),
                ),
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
            onPressed: name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, name.text.trim()),
            icon: const Icon(Icons.sell_outlined, size: 17),
            label: Text(tr(context, 'Crear categoría')),
          ),
        ],
      ),
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
      appBar: AppBar(title: Text(tr(context, 'Buscar apuntes'))),
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
