import 'dart:io';
import 'dart:math';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/security/secure_store.dart';
import '../features/notes/domain/ports.dart';
import '../features/notes/domain/use_cases.dart';
import '../features/notes/data/local/database.dart';
import '../features/notes/data/local_notes_repository.dart';
import '../features/capture/data/local_media_repository.dart';
import '../features/capture/data/device_speech.dart';
import '../features/ai/data/ai_services.dart';
import '../features/auth/data/google_identity.dart';
import '../features/export/data/document_export.dart';

final sl = GetIt.instance;
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${Random.secure().nextInt(1 << 32).toRadixString(36)}';
Future<void> configureApp() async {
  final root = await getApplicationSupportDirectory();
  await root.create(recursive: true);
  final cache = await getTemporaryDirectory();
  final file = File(p.join(root.path, 'draftai.sqlite'));
  final vault = await VaultCipher.open(
    SystemSecureStore(),
    existingData: await file.exists(),
  );
  final db = AppDatabase.file(file);
  sl.registerSingleton(db);
  final notes = LocalNotesRepository(db, vault);
  sl.registerSingleton<NotesRepository>(notes);
  sl.registerSingleton(NoteActions(notes, DateTime.now, newId));
  sl.registerSingleton(AiPolicy(notes, DateTime.now));
  final media = LocalMediaRepository(
    Directory(p.join(root.path, 'media')),
    cache,
    vault,
    newId,
  );
  sl.registerSingleton<MediaRepository>(media);
  sl.registerSingleton<ExportService>(DocumentExport(media, cache));
  sl.registerSingleton<SpeechService>(DeviceSpeech());
  final identity = GoogleIdentity();
  if (identity.configured) {
    try {
      await identity.idToken().timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Local notes remain usable without remote identity. */
    }
  }
  sl.registerSingleton<IdentityService>(identity);
  const endpoint = String.fromEnvironment('AI_BASE_URL');
  sl.registerSingleton<AiService>(
    endpoint.isEmpty
        ? DemonstrationAi()
        : RemoteAi(
            Uri.parse(endpoint.endsWith('/') ? endpoint : '$endpoint/'),
            identity,
            http.Client(),
          ),
  );
}
