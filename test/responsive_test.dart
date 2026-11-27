import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/main.dart';

import 'support/memory_notes.dart';

import 'package:draft_ai/features/notes/presentation/note_page.dart';

import 'package:draft_ai/features/notes/domain/use_cases.dart';

import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/core/security/secure_store.dart';
import 'package:draft_ai/features/ai/data/gateway_ai.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:draft_ai/features/settings/presentation/settings_pages.dart';

import 'ai_adapter_test.dart' show IdentityStub;

void main() {
  for (final width in [320.0, 390.0, 600.0, 1000.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('welcome and library fit width $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = MemoryNotes();
        final profiles = MemoryProfiles();
        final client = MockClient((_) async => http.Response('{}', 401));
        addTearDown(client.close);
        final ai = GatewayAi(MemorySecureStore(), client, profiles);
        await ai.loadProfile();
        final now = DateTime.now();
        repo.folders['f'] = const Folder('f', 'Pruebas', 0xFFFF0000);
        repo.notes['n'] = Note(
          id: 'n',
          folderId: 'f',
          title: 'Apunte',
          createdAt: now,
          updatedAt: now,
        );
        var seq = 0;
        final container = ProviderContainer(
          overrides: [
            notesPort.overrideWithValue(repo),
            identityPort.overrideWithValue(IdentityStub()),
            profileVaultPort.overrideWithValue(profiles),
            actionsPort.overrideWithValue(
              NoteActions(repo, DateTime.now, () => 'id${seq++}'),
            ),
            idPort.overrideWithValue(() => 'id${seq++}'),
            aiPort.overrideWithValue(ai),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await repo.close();
        });
        final originalError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          originalError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalError);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DraftApp(),
          ),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('guest-enter')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Tus carpetas'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Inspect the profile's interactive tiles before the plan table.
        final rootContext = tester.element(find.text('Tus carpetas'));
        Navigator.of(rootContext)
            .push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Conectar IA'));
        await tester.tap(find.text('Conectar IA'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        Navigator.of(rootContext).pop();
        await tester.pumpAndSettle();
        final context = tester.element(find.text('Tus carpetas'));
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                NotePage(note: repo.current.active.first, edit: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
