import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/main.dart';

import 'support/memory_notes.dart';

import 'package:draft_ai/features/notes/presentation/note_page.dart';

import 'package:draft_ai/features/notes/domain/use_cases.dart';

import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/ai/data/ai_services.dart';
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
        var seq = 0;
        final container = ProviderContainer(
          overrides: [
            notesPort.overrideWithValue(repo),
            identityPort.overrideWithValue(IdentityStub()),
            policyPort.overrideWithValue(AiPolicy(repo, DateTime.now)),
            actionsPort.overrideWithValue(
              NoteActions(repo, DateTime.now, () => 'id${seq++}'),
            ),
            idPort.overrideWithValue(() => 'id${seq++}'),
            aiPort.overrideWithValue(DemonstrationAi()),
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
        await container.read(controllerProvider.notifier).loadExamples();
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Tus carpetas'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Also inspect dense plan comparison at the same breakpoint.
        final context = tester.element(find.text('Tus carpetas'));
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const PlansPage()));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
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
