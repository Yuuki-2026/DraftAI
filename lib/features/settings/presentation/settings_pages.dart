import 'example_page.dart';
import '../../../core/presentation/strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../notes/presentation/controller.dart';
import '../../ai/presentation/ai_pages.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool busy = false;
  Future<void> _enter(bool google) async {
    setState(() => busy = true);
    await runAction(
      context,
      () => ref.read(controllerProvider.notifier).enter(google: google),
    );
    if (mounted) setState(() => busy = false);
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
                SizedBox(height: 32),
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
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Perfil'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 720,
          child: ListView(
            children: [
              SizedBox(height: 16),
              Surface(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.mid,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/12225881.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            identity.displayName ?? 'Modo invitado',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Meta(tr(context, 'Datos en este dispositivo')),
                        ],
                      ),
                    ),
                    Pill(settings?.pro == true ? 'Pro · demo' : 'Gratis'),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(tr(context, 'Acciones de IA'))),
                        Pill(
                          tr(
                            context,
                            '${settings?.used ?? 0} de ${settings?.pro == true ? 10 : 2} hoy',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value:
                          ((settings?.used ?? 0) /
                                  (settings?.pro == true ? 10 : 2))
                              .clamp(0, 1),
                    ),
                    SizedBox(height: 10),
                    Text(
                      tr(
                        context,
                        'Resúmenes y mejoras comparten el límite diario. El contador se renueva cada día.',
                      ),
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
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
    String subtitle,
    Widget page,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, size: 21),
        title: Text(tr(c, title), style: const TextStyle(fontSize: 13)),
        subtitle: Text(tr(c, subtitle), style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => openPage(c, page),
      ),
    ),
  );
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
                pro ? 'Pro · demostración' : 'Gratis',
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
                        pro ? 'Volver a Gratis' : 'Activar vista previa de Pro',
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
                      ['OCR remoto', 'No', 'Preparado'],
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
                                  s,
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
                  'Sin proveedor configurado, el resumen es una extracción local de frases y el OCR solo muestra un ejemplo editable. No se ejecuta OCR real.',
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
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Preferencias'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: ListView(
            children: [
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
                        title: Text(language.$2),
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
              SizedBox(height: 28),
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
                  busy ? 'Preparando copia…' : 'Exportar copia local',
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
            Center(child: Meta(tr(context, 'Versión 0.2.0 · Build 3'))),
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
                applicationVersion: '0.2.0',
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
              'Los apuntes, títulos, resúmenes y archivos se cifran con AES-GCM en el espacio privado del dispositivo. La clave se guarda con el almacén seguro del sistema. Identificadores y fechas quedan en SQLite para sus relaciones e índices.',
            ),
            (
              'Servicios externos',
              'Google se utiliza para autenticar cuando lo solicitas. No sincroniza notas. El servicio de IA recibe solo el contenido que confirmes enviar. Su proveedor y tratamiento deben revisarse al configurar el servicio.',
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
              'DraftAI permite crear y organizar notas con texto e imágenes guardadas en el dispositivo. Puedes agruparlas en carpetas y categorías, buscar su contenido y exportarlas para compartir. Los planes y precios son demostrativos; no se procesan pagos.',
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
              'Usa + Nuevo para cámara, imágenes o archivos. Revisa cada elemento y elige carpeta/categoría. Gratis guarda las imágenes sin OCR. Puedes añadir archivos también desde el editor.',
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
      appBar: AppBar(title: Text(title)),
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
