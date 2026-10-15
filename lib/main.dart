import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/di.dart';
import 'core/presentation/design.dart';
import 'features/notes/domain/ports.dart';
import 'features/notes/domain/use_cases.dart';
import 'features/notes/presentation/controller.dart';
import 'features/notes/presentation/library_page.dart';
import 'features/settings/presentation/settings_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  LicenseRegistry.addLicense(() async* {
    for (final item in [
      ('Inter', 'OFL-Inter.txt'),
      ('JetBrains Mono', 'OFL-JetBrainsMono.txt'),
      ('Noto Sans Math', 'OFL-NotoSansMath.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        item.$1,
      ], await rootBundle.loadString('assets/fonts/${item.$2}'));
    }
  });
  try {
    await configureApp();
    runApp(
      ProviderScope(
        overrides: [
          notesPort.overrideWithValue(sl<NotesRepository>()),
          mediaPort.overrideWithValue(sl<MediaRepository>()),
          exportPort.overrideWithValue(sl<ExportService>()),
          aiPort.overrideWithValue(sl<AiService>()),
          speechPort.overrideWithValue(sl<SpeechService>()),
          identityPort.overrideWithValue(sl<IdentityService>()),
          actionsPort.overrideWithValue(sl<NoteActions>()),
          policyPort.overrideWithValue(sl<AiPolicy>()),
          idPort.overrideWithValue(newId),
        ],
        child: const DraftApp(),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 20),
                  const Text('No se pudo abrir tu biblioteca'),
                  const SizedBox(height: 12),
                  Text('$e'),
                  const SizedBox(height: 20),
                  const Text(
                    'Tus datos no se han borrado. Cierra la app, desbloquea el dispositivo y vuelve a intentar.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DraftApp extends ConsumerWidget {
  const DraftApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(controllerProvider);
    final theme = settings.value?.theme ?? 'dark';
    return MaterialApp(
      title: 'DraftAI',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: theme == 'system'
          ? ThemeMode.system
          : theme == 'light'
          ? ThemeMode.light
          : ThemeMode.dark,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: settings.when(
        data: (s) => s.entered ? const LibraryPage() : const WelcomePage(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      ),
    );
  }
}
