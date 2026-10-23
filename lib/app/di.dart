import 'dart:math';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/security/secure_store.dart';
import '../features/notes/domain/ports.dart';
import '../features/notes/domain/use_cases.dart';
import '../features/capture/data/device_speech.dart';
import '../features/notes/data/example_library.dart';
import '../features/ai/data/gateway_ai.dart';
import '../features/auth/data/google_identity.dart';
import '../features/auth/data/profile_vaults.dart';
import '../features/export/data/document_export.dart';

final sl = GetIt.instance;
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${Random.secure().nextInt(1 << 32).toRadixString(36)}';
Future<void> configureApp() async {
  final root = await getApplicationSupportDirectory();
  await root.create(recursive: true);
  final cache = await getTemporaryDirectory();
  final secure = SystemSecureStore();
  final identity = GoogleIdentity();
  try {
    await identity.initialize();
  } catch (_) {
    // Guest notes remain available when Firebase is not configured yet.
  }
  final profiles = ProfileVaultManager(
    root: root,
    cache: cache,
    secure: secure,
    newId: newId,
  );
  final restoredUser = identity.userId;
  await profiles.activate(restoredUser ?? guestOwnerId);
  if (restoredUser != null &&
      await profiles.activeNotes.preference('entered') != 'true') {
    // An interrupted sign-in should return to Guest so its migration question
    // can be shown again instead of silently hiding that library.
    await identity.signOut();
    await profiles.activate(guestOwnerId);
  }
  final notes = ProfiledNotesRepository(profiles);
  final media = ProfiledMediaRepository(profiles);
  sl.registerSingleton<NotesRepository>(notes);
  sl.registerSingleton<MediaRepository>(media);
  sl.registerSingleton<ProfileVaultService>(profiles);
  sl.registerSingleton<ProfileVaultManager>(profiles);
  sl.registerSingleton(NoteActions(notes, DateTime.now, newId));
  sl.registerSingleton(AiPolicy(notes, DateTime.now));
  sl.registerSingleton<ExportService>(DocumentExport(media, cache));
  sl.registerSingleton<ExampleService>(ExampleLibrary(notes, media, newId));
  sl.registerSingleton<SpeechService>(DeviceSpeech());
  sl.registerSingleton<IdentityService>(identity);
  final gateway = GatewayAi(SystemSecureStore(), http.Client(), identity);
  await gateway.initialize();
  sl.registerSingleton<AiService>(gateway);
}
