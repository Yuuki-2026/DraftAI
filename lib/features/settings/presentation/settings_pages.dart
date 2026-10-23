import '../../ai/presentation/ai_quota_card.dart';
import 'example_page.dart';
import '../../../core/presentation/strings.dart';
import '../../../core/presentation/user_avatar.dart';

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/presentation/design.dart';
import '../../notes/presentation/controller.dart';
import '../../notes/domain/ports.dart';
import '../../notes/presentation/paper_pattern.dart';
import '../../ai/presentation/ai_pages.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool busy = false;
  Future<void> _enter(bool google) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await runAction(context, () async {
        final controller = ref.read(controllerProvider.notifier);
        if (!google) {
          await controller.enterGuest();
          return;
        }

        final identity = ref.read(identityPort);
        final english = Localizations.localeOf(context).languageCode == 'en';
        await identity.signIn();
        var completed = false;
        try {
          if (!mounted) return;
          var moveGuestNotes = false;
          var neverAskAgain = false;
          final profiles = ref.read(profileVaultPort);
          if (profiles.activeOwnerId == guestProfileId &&
              await profiles.guestMovePromptEnabled()) {
            final count = await profiles.guestNoteCount();
            if (count > 0) {
              if (!mounted) return;
              final accountName = identity.displayName ?? 'Google';
              var suppressPrompt = false;
              final choice = await showDialog<_GuestMoveDecision>(
                context: context,
                builder: (dialogContext) => StatefulBuilder(
                  builder: (context, setDialogState) => AlertDialog(
                    title: Text(
                      english
                          ? 'Move $count notes to $accountName?'
                          : '¿Mover $count apuntes a $accountName?',
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          english
                              ? 'They will be moved to this account’s encrypted vault on this phone. DraftAI verifies the copy before removing them from Guest. Cloud sync is not available yet.'
                              : 'Se moverán a la bóveda cifrada de esta cuenta en este teléfono. DraftAI verificará la copia antes de retirarlos de Invitado. Aún no hay sincronización en la nube.',
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: suppressPrompt,
                          onChanged: (value) => setDialogState(
                            () => suppressPrompt = value ?? false,
                          ),
                          title: Text(
                            tr(
                              context,
                              'No volver a mostrar; puedes moverlos desde Preferencias.',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          _GuestMoveDecision(false, suppressPrompt),
                        ),
                        child: Text(tr(dialogContext, 'Dejar en Invitado')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          _GuestMoveDecision(true, suppressPrompt),
                        ),
                        child: Text(tr(dialogContext, 'Mover apuntes')),
                      ),
                    ],
                  ),
                ),
              );
              if (choice == null || !mounted) return;
              moveGuestNotes = choice.move;
              neverAskAgain = choice.neverAskAgain;
            }
          }
          await controller.enterGoogle(moveGuestNotes: moveGuestNotes);
          if (neverAskAgain) await profiles.setGuestMovePromptEnabled(false);
          completed = true;
        } finally {
          if (!completed) await identity.signOut();
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ResponsiveBody(
        maxWidth: 430,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 82,
                      height: 82,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  tr(context, 'DraftAI'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Center(child: Pill(tr(context, 'Beta · En pruebas'))),
                SizedBox(height: 24),
                Text(
                  tr(context, 'Bienvenido'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 9),
                Text(
                  tr(
                    context,
                    'Tus apuntes, imágenes y aprendizajes organizados en un solo espacio.',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : () => _enter(true),
                  icon: const Icon(Icons.account_circle_outlined, size: 20),
                  label: Text(tr(context, 'Iniciar sesión con Google')),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('guest-enter'),
                  onPressed: busy ? null : () => _enter(false),
                  child: Text(tr(context, 'Continuar sin cuenta')),
                ),
                if (busy)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                SizedBox(height: 14),
                TextButton(
                  onPressed: () =>
                      openPage(context, const InformationPage(kind: 'privacy')),
                  child: Text(
                    tr(context, 'Privacidad'),
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(controllerProvider).value;
    final identity = ref.read(identityPort);
    final googleAccountAvailable =
        identity.configured &&
        identity is AccountIdentityService &&
        (identity as AccountIdentityService).userId != null;
    final defaultName = identity.displayName ?? tr(context, 'Modo invitado');
    final profileName = settings?.profileName.trim().isNotEmpty == true
        ? settings!.profileName.trim()
        : defaultName;

    Future<void> editName() async {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => _ProfileNameDialog(name: profileName),
      );
      if (result == null || !context.mounted) return;
      await runAction(
        context,
        () => ref
            .read(controllerProvider.notifier)
            .saveProfile(name: result, image: settings?.profileImage ?? ''),
      );
    }

    Future<void> editPhoto() async {
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        if (file == null || !context.mounted) return;
        final bytes = await file.readAsBytes();
        if (!context.mounted) return;
        final cropped = await showDialog<Uint8List>(
          context: context,
          builder: (_) => _ProfilePhotoCropDialog(bytes: bytes),
        );
        if (cropped == null || !context.mounted) return;
        await runAction(
          context,
          () => ref
              .read(controllerProvider.notifier)
              .saveProfile(
                name: settings?.profileName ?? '',
                image: base64Encode(cropped),
              ),
        );
      } catch (_) {
        if (context.mounted) {
          message(context, tr(context, 'No se pudo abrir la imagen.'));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Perfil'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 720,
          child: ListView(
            children: [
              SizedBox(height: 16),
              Surface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 22,
                ),
                child: Column(
                  children: [
                    Semantics(
                      button: true,
                      label: tr(context, 'Cambiar foto de perfil'),
                      child: InkWell(
                        onTap: editPhoto,
                        customBorder: const CircleBorder(),
                        child: Stack(
                          children: [
                            UserAvatar(size: 116),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            profileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: tr(context, 'Editar nombre'),
                          onPressed: editName,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                    Meta(tr(context, 'Datos en este dispositivo')),
                    const SizedBox(height: 8),
                    Pill(
                      googleAccountAvailable
                          ? settings?.pro == true
                                ? 'Pro · demo'
                                : 'Gratis'
                          : tr(context, 'Invitado'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              const AiQuotaCard(),
              SizedBox(height: 16),
              if (!googleAccountAvailable)
                _item(
                  context,
                  Icons.key_outlined,
                  'Conectar IA',
                  '',
                  const AiPage(),
                ),
              if (googleAccountAvailable)
                _item(
                  context,
                  Icons.auto_awesome_outlined,
                  settings?.pro == true
                      ? 'Plan Pro demostrativo'
                      : 'Ver Plan Pro',
                  'Sin cobros ni compra real',
                  const PlansPage(),
                ),
              _item(
                context,
                Icons.tune,
                'Preferencias',
                'Tema y ajustes locales',
                const PreferencesPage(),
              ),
              _item(
                context,
                Icons.storage_outlined,
                'Almacenamiento',
                'Notas e imágenes del dispositivo',
                const StoragePage(),
              ),
              _item(
                context,
                Icons.psychology_outlined,
                'Herramientas de IA',
                'Resúmenes y contexto para otras herramientas',
                const AiPage(),
              ),
              _item(
                context,
                Icons.science_outlined,
                'Biblioteca de prueba',
                'Cargar o eliminar ejemplos',
                const ExamplePage(),
              ),
              _item(
                context,
                Icons.info_outline,
                'Ayuda y acerca de',
                'Guías, privacidad y licencias',
                const AboutPage(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, size: 20),
                title: Text(
                  tr(context, 'Salir'),
                  style: TextStyle(fontSize: 13),
                ),
                onTap: () => runAction(context, () async {
                  await ref.read(controllerProvider.notifier).leave();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext c,
    IconData icon,
    String title,
    String? subtitle,
    Widget page,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, size: 21),
        title: Text(tr(c, title), style: const TextStyle(fontSize: 13)),
        subtitle: subtitle == null || subtitle.isEmpty
            ? null
            : Text(tr(c, subtitle), style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => openPage(c, page),
      ),
    ),
  );
}

class _GuestMoveDecision {
  final bool move;
  final bool neverAskAgain;
  const _GuestMoveDecision(this.move, this.neverAskAgain);
}

class _ProfileNameDialog extends StatefulWidget {
  final String name;
  const _ProfileNameDialog({required this.name});

  @override
  State<_ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<_ProfileNameDialog> {
  late final TextEditingController name;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'Editar nombre')),
      content: TextField(
        controller: name,
        autofocus: true,
        maxLength: 40,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: tr(context, 'Nombre')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancelar')),
        ),
        FilledButton(
          onPressed: name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, name.text.trim()),
          child: Text(tr(context, 'Guardar')),
        ),
      ],
    );
  }
}

class _ProfilePhotoCropDialog extends StatefulWidget {
  final Uint8List bytes;
  const _ProfilePhotoCropDialog({required this.bytes});

  @override
  State<_ProfilePhotoCropDialog> createState() =>
      _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<_ProfilePhotoCropDialog> {
  final cropKey = GlobalKey();
  final transform = TransformationController();
  late final Future<Size> sourceSize = _readImageSize();
  bool saving = false, imageReady = false;

  Future<Size> _readImageSize() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('No crop render boundary');
      final original = await sourceSize;
      final side = math.min(original.width, original.height);
      final cropDimension = math.min(boundary.size.width, boundary.size.height);
      final pixelRatio = (side / cropDimension).clamp(1.0, 8.0).toDouble();
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('No crop image bytes');
      if (mounted) Navigator.pop(context, data.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        message(context, tr(context, 'No se pudo guardar el recorte.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final cropDimension = math
        .min(screen.width - 128, screen.height - 260)
        .clamp(96.0, 320.0)
        .toDouble();
    return AlertDialog(
      title: Text(tr(context, 'Ajustar foto de perfil')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(
              context,
              'Arrastra la imagen o usa dos dedos para ajustar el encuadre.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FutureBuilder<Size>(
            future: sourceSize,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(tr(context, 'No se pudo abrir la imagen.'));
              }
              if (!snapshot.hasData) {
                return SizedBox.square(
                  dimension: cropDimension,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final source = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : cropDimension;
                  final maxHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : cropDimension;
                  final side = math
                      .min(cropDimension, math.min(maxWidth, maxHeight))
                      .clamp(1.0, cropDimension)
                      .toDouble();
                  final aspect = source.width / source.height;
                  final imageWidth = aspect >= 1 ? side * aspect : side;
                  final imageHeight = aspect >= 1 ? side : side / aspect;
                  return Center(
                    child: RepaintBoundary(
                      key: cropKey,
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: InteractiveViewer(
                                  transformationController: transform,
                                  constrained: false,
                                  alignment: Alignment.center,
                                  minScale: 1,
                                  maxScale: 4,
                                  boundaryMargin: const EdgeInsets.all(80),
                                  child: Image.memory(
                                    widget.bytes,
                                    width: imageWidth,
                                    height: imageHeight,
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                    frameBuilder:
                                        (context, child, frame, sync) {
                                          if (sync || frame != null) {
                                            if (!imageReady) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    if (mounted) {
                                                      setState(
                                                        () => imageReady = true,
                                                      );
                                                    }
                                                  });
                                            }
                                            return child;
                                          }
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        },
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: .75),
                                      width: 1,
                                    ),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(tr(context, 'Cancelar')),
        ),
        FilledButton.icon(
          onPressed: saving || !imageReady ? null : save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(tr(context, 'Usar foto')),
        ),
      ],
    );
  }
}

class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pro = ref.watch(controllerProvider).value?.pro ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Suscripción'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: ListView(
            children: [
              SizedBox(height: 18),
              Meta(tr(context, 'PLAN ACTUAL')),
              SizedBox(height: 8),
              Text(
                tr(context, pro ? 'Pro · demostración' : 'Gratis'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'Explora las herramientas inteligentes. Los planes son demostrativos: no se realizan cobros.',
                ),
              ),
              SizedBox(height: 16),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Meta(tr(context, 'PLAN PRO'))),
                        Pill(tr(context, 'Vista previa')),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      tr(context, 'Hasta 10 acciones de IA al día'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      tr(context, '\$4.99 / mes'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Meta(tr(context, 'Precio ilustrativo · sin facturación')),
                    SizedBox(height: 18),
                    FilledButton.icon(
                      key: const Key('toggle-pro'),
                      onPressed: () => runAction(context, () async {
                        await ref.read(controllerProvider.notifier).plan(!pro);
                        if (context.mounted) {
                          message(
                            context,
                            pro
                                ? 'Volviste a Gratis. Tus apuntes se conservan.'
                                : 'Vista previa de Pro activada. No se ha realizado ningún cobro.',
                          );
                        }
                      }),
                      icon: Icon(pro ? Icons.undo : Icons.check, size: 18),
                      label: Text(
                        tr(
                          context,
                          pro
                              ? 'Volver a Gratis'
                              : 'Activar vista previa de Pro',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SectionTitle('Comparativa de planes'),
              Surface(
                padding: EdgeInsets.zero,
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(),
                    2: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    for (final row in [
                      ['Funciones', 'Gratis', 'Pro demo'],
                      ['Apuntes e imágenes', 'Sí', 'Sí'],
                      ['Acciones IA al día', '2', '10'],
                      [
                        'Lectura de fuentes con IA',
                        'No',
                        'Acceso Pro autorizado',
                      ],
                      ['Exportar PDF, Word, texto', 'Sí', 'Sí'],
                      ['Contexto para IA externa', 'Sí', 'Sí'],
                      ['Almacenamiento local', 'Sí', 'Sí'],
                    ])
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        children: row
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.all(11),
                                child: Text(
                                  tr(context, s),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                tr(
                  context,
                  'La IA necesita conexión. Gratis usa Groq; Pro autorizado usa GPT-5 nano para texto, imágenes, PDF y TXT/MD. Cada resultado indica el modelo utilizado. Los planes no procesan pagos.',
                ),
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(controllerProvider).value;
    const styles = [
      ('plain', 'Liso'),
      ('lines', 'Renglones'),
      ('grid', 'Cuadrícula'),
      ('dots', 'Puntos'),
      ('spaced', 'Interlineado amplio'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Preferencias'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: ListView(
            children: [
              SectionTitle('Estilo de página'),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr(context, 'Elige el fondo de tus apuntes.')),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final style in styles)
                            SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: _PaperStyleChoice(
                                id: style.$1,
                                label: style.$2,
                                selected:
                                    (settings?.paperStyle ?? 'plain') ==
                                    style.$1,
                                onTap: () => runAction(
                                  context,
                                  () => ref
                                      .read(controllerProvider.notifier)
                                      .paperStyle(style.$1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SectionTitle('Idioma'),
              Surface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final language in [
                      ('es', 'Español (América Latina)', 'ES'),
                      ('en', 'English', 'EN'),
                    ])
                      ListTile(
                        leading: const Icon(Icons.translate),
                        title: Text(tr(context, language.$2)),
                        trailing: Icon(
                          (settings?.locale ?? 'es') == language.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onTap: () => runAction(
                          context,
                          () => ref
                              .read(controllerProvider.notifier)
                              .locale(language.$1),
                        ),
                      ),
                  ],
                ),
              ),
              SectionTitle('Fuente de la aplicación'),
              Surface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final font in [
                      ('Inter', 'Inter', Icons.text_fields),
                      ('serif', 'Clásica', Icons.menu_book_outlined),
                      ('monospace', 'Monoespaciada', Icons.code),
                    ])
                      ListTile(
                        leading: Icon(font.$3),
                        title: Text(
                          tr(context, font.$2),
                          style: TextStyle(fontFamily: font.$1),
                        ),
                        trailing: Icon(
                          (settings?.fontFamily ?? 'Inter') == font.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onTap: () => runAction(
                          context,
                          () => ref
                              .read(controllerProvider.notifier)
                              .fontFamily(font.$1),
                        ),
                      ),
                  ],
                ),
              ),
              SectionTitle('Traslado de apuntes'),
              const _GuestTransferSettings(),
              SectionTitle('Tema visual'),
              Surface(
                child: Column(
                  children: [
                    for (final v in [
                      ('dark', 'Oscuro puro', Icons.dark_mode_outlined),
                      ('light', 'Claro', Icons.light_mode_outlined),
                      ('system', 'Automático', Icons.brightness_auto_outlined),
                    ])
                      ListTile(
                        title: Text(tr(context, v.$2)),
                        leading: Icon(v.$3),
                        trailing: Icon(
                          (settings?.theme ?? 'dark') == v.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onTap: () => runAction(
                          context,
                          () =>
                              ref.read(controllerProvider.notifier).theme(v.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestTransferSettings extends ConsumerStatefulWidget {
  const _GuestTransferSettings();

  @override
  ConsumerState<_GuestTransferSettings> createState() =>
      _GuestTransferSettingsState();
}

class _GuestTransferSettingsState
    extends ConsumerState<_GuestTransferSettings> {
  bool? promptEnabled;
  int guestNotes = 0;
  bool loading = true;
  bool moving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = ref.read(profileVaultPort);
    final enabled = await profiles.guestMovePromptEnabled();
    final count = await profiles.guestNoteCount();
    if (!mounted) return;
    setState(() {
      promptEnabled = enabled;
      guestNotes = count;
      loading = false;
    });
  }

  Future<void> _move(String ownerId) async {
    if (moving) return;
    final count = guestNotes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, 'Importar apuntes de Invitado')),
        content: Text(
          tr(
            dialogContext,
            'Se moverán $count apuntes a la bóveda cifrada de esta cuenta. Los datos de Invitado solo se retirarán después de verificar la copia.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(dialogContext, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(dialogContext, 'Mover apuntes')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => moving = true);
    await runAction(context, () async {
      await ref.read(profileVaultPort).moveGuestTo(ownerId);
      ref.invalidate(libraryProvider);
      await ref.read(controllerProvider.notifier).refresh();
      await _load();
    });
    if (mounted) setState(() => moving = false);
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.read(identityPort);
    final ownerId = identity is AccountIdentityService
        ? (identity as AccountIdentityService).userId
        : null;
    return Surface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            value: promptEnabled ?? true,
            onChanged: loading
                ? null
                : (value) async {
                    setState(() => promptEnabled = value);
                    await runAction(
                      context,
                      () => ref
                          .read(profileVaultPort)
                          .setGuestMovePromptEnabled(value),
                    );
                    await _load();
                  },
            title: Text(tr(context, 'Recordarme mover apuntes de Invitado')),
            subtitle: Text(
              tr(context, 'Puedes cambiar esta opción cuando quieras.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (ownerId != null && !loading && guestNotes > 0) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.move_to_inbox_outlined),
              title: Text(tr(context, 'Importar apuntes de Invitado')),
              subtitle: Text(
                tr(context, '$guestNotes apuntes disponibles'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: moving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: moving ? null : () => _move(ownerId),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaperStyleChoice extends StatelessWidget {
  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaperStyleChoice({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: CustomPaint(
                  painter: PaperPatternPainter(
                    style: id,
                    color: scheme.onSurface,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                tr(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoragePage extends ConsumerStatefulWidget {
  const StoragePage({super.key});
  @override
  ConsumerState<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends ConsumerState<StoragePage> {
  int? bytes;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final n = await ref.read(mediaPort).storageBytes();
    if (mounted) setState(() => bytes = n);
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Almacenamiento'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: ListView(
            children: [
              SectionTitle('Capacidad local'),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bytes == null ? 'Calculando…' : byteLabel(bytes!),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Meta(tr(context, 'Archivos adjuntos cifrados')),
                    SizedBox(height: 16),
                    Text(
                      tr(
                        context,
                        '${lib?.active.length ?? 0} apuntes · ${lib?.folders.length ?? 0} carpetas · ${lib?.trash.length ?? 0} en papelera',
                      ),
                    ),
                  ],
                ),
              ),
              SectionTitle('Acciones de mantenimiento'),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => runAction(context, () async {
                        final freed = await ref.read(mediaPort).clearCache();
                        if (context.mounted) {
                          message(
                            context,
                            'Caché temporal limpia: ${byteLabel(freed)} liberados.',
                          );
                        }
                        await _refresh();
                      }),
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: Text(tr(context, 'Limpiar caché de exportaciones')),
              ),
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy || lib == null
                    ? null
                    : () => runAction(context, () async {
                        if (!await confirm(
                          context,
                          'Exportar copia local',
                          'La copia ZIP contiene tus notas e imágenes sin cifrar para que puedas recuperarlas fuera de DraftAI. Guárdala en un lugar protegido.',
                        )) {
                          return;
                        }
                        setState(() => busy = true);
                        try {
                          await ref.read(exportPort).backup(lib);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      }),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: Text(
                  tr(
                    context,
                    busy ? 'Preparando copia…' : 'Exportar copia local',
                  ),
                ),
              ),
              SizedBox(height: 16),
              Surface(
                child: Text(
                  tr(
                    context,
                    'Tus apuntes e imágenes permanecen cifrados en el almacenamiento privado de la app. La clave se protege con Keystore/Keychain. No existe sincronización entre dispositivos.',
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                tr(
                  context,
                  'Desinstalar la app elimina sus datos y su clave. Exporta antes los apuntes que quieras conservar.',
                ),
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Acerca de DraftAI'))),
    body: SafeArea(
      child: ResponsiveBody(
        maxWidth: 640,
        child: ListView(
          children: [
            SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 70,
                height: 70,
              ),
            ),
            SizedBox(height: 14),
            Center(
              child: Text(
                tr(context, 'DraftAI'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
            ),
            Center(child: Meta(tr(context, 'Versión 0.2.3-beta.4 · Build 9'))),
            SizedBox(height: 20),
            Surface(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Pill(tr(context, 'Datos locales')),
                  Pill(tr(context, 'Almacén cifrado')),
                  Pill(tr(context, 'Android primero')),
                ],
              ),
            ),
            SectionTitle('Información'),
            for (final item in [
              ('help', 'Centro de ayuda', Icons.help_outline),
              ('terms', 'Términos de uso', Icons.description_outlined),
              ('privacy', 'Política de privacidad', Icons.shield_outlined),
            ])
              ListTile(
                leading: Icon(item.$3, size: 21),
                title: Text(
                  tr(context, item.$2),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => openPage(context, InformationPage(kind: item.$1)),
              ),
            ListTile(
              leading: const Icon(Icons.code, size: 21),
              title: Text(
                tr(context, 'Licencias'),
                style: TextStyle(fontSize: 13),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'DraftAI',
                applicationVersion: '0.2.3-beta.4',
              ),
            ),
            SizedBox(height: 24),
            Center(child: Meta(tr(context, 'TUS IDEAS, SIEMPRE A MANO'))),
            SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

class InformationPage extends StatelessWidget {
  final String kind;
  const InformationPage({super.key, required this.kind});
  @override
  Widget build(BuildContext context) {
    final title = kind == 'privacy'
        ? 'Política de privacidad'
        : kind == 'terms'
        ? 'Términos de uso'
        : 'Centro de ayuda';
    final sections = kind == 'privacy'
        ? [
            (
              'Almacenamiento local',
              'Los apuntes y archivos se cifran en el teléfono con una clave protegida por el sistema. Invitado y cada cuenta de Google tienen una bóveda local independiente. Las notas todavía no se sincronizan con la nube.',
            ),
            (
              'Servicios externos',
              'Google se usa para identificar la cuenta y abrir su bóveda local. Las funciones de IA envían al servicio externo únicamente el contenido que confirmes procesar. Las notas y sus archivos permanecen cifrados en el teléfono hasta habilitar la sincronización en la nube.',
            ),
            (
              'Voz y permisos',
              'La voz usa el reconocedor del sistema, que puede necesitar red. Cámara y micrófono se solicitan al usarlos. No se incluye publicidad ni analítica de seguimiento.',
            ),
            (
              'Exportación y eliminación',
              'Los archivos que exportas se pueden leer fuera de la aplicación. Limpiar caché elimina las copias temporales de exportación. La papelera permite restaurar notas antes de eliminarlas definitivamente.',
            ),
          ]
        : kind == 'terms'
        ? [
            (
              'Uso de DraftAI',
              'DraftAI permite crear y organizar notas con texto e imágenes guardadas en el dispositivo. Puedes agruparlas en carpetas, buscar su contenido y exportarlas para compartir. Los planes y precios son demostrativos; no se procesan pagos.',
            ),
            (
              'Revisión del contenido',
              'Revisa cualquier extracción o resumen antes de guardarlo. Los modelos externos pueden cometer errores. Sin API configurada, las demostraciones se identifican expresamente.',
            ),
            (
              'Conservación',
              'Conserva copias de los apuntes importantes. Al desinstalar se eliminan los datos locales. La aplicación no mantiene copias en un servidor.',
            ),
          ]
        : [
            (
              'Crear tu primera nota',
              'En Inicio pulsa Nueva nota o + Nuevo → Escribir nota. Elige una carpeta. El editor guarda automáticamente y permite guardar de forma explícita.',
            ),
            (
              'Añadir imágenes y PDF',
              'Usa + Nuevo para cámara, imágenes o archivos. Revisa cada elemento y elige carpeta. Gratis guarda las imágenes sin OCR. Puedes añadir archivos también desde el editor.',
            ),
            (
              'Revisar cambios',
              'Abre el historial en la esquina superior del apunte. Puedes restaurar una versión anterior. La barra de edición también incluye deshacer y rehacer.',
            ),
            (
              'IA y contexto externo',
              'Desde Más → Herramientas de IA selecciona temas o fechas. Genera un resumen o prepara un prompt para copiar a una herramienta externa.',
            ),
            (
              'Recuperar y exportar',
              'Restaura desde Papelera. En Exportar elige PDF, Word, texto o Markdown. Almacenamiento permite crear una copia ZIP local.',
            ),
          ];
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, title))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 720,
          child: ListView(
            children: [
              for (final s in sections) ...[
                SectionTitle(tr(context, s.$1)),
                Surface(child: SelectableText(tr(context, s.$2))),
              ],
              SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
