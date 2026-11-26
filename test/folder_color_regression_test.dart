import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/use_cases.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/notes/presentation/library_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_notes.dart';

void main() {
  testWidgets(
    'El tono permanece en el extremo derecho hasta aplicar el color',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const folder = Folder('f', 'Carpeta de prueba', 0xFF00FFFF);
      final repo = MemoryNotes();
      repo.folders[folder.id] = folder;
      addTearDown(repo.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesPort.overrideWithValue(repo),
            policyPort.overrideWithValue(AiPolicy(repo, DateTime.now)),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () =>
                      editFolder(context, ref, folder: folder, colorOnly: true),
                  child: const Text('Abrir selector'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir selector'));
      await tester.pumpAndSettle();
      final slider = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_HueSpectrumSlider',
      );
      final marker = find.descendant(
        of: slider,
        matching: find.byType(Positioned),
      );
      double position() {
        final track = tester.getRect(slider);
        final thumb = tester.getRect(marker);
        return (thumb.left - track.left) / (track.width - thumb.width);
      }

      Future<void> moveToEnd() async {
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        final bar = tester.getRect(slider);
        final drag = await tester.startGesture(tester.getCenter(marker));
        await drag.moveBy(const Offset(kPanSlop + 4, 0));
        await drag.moveTo(bar.centerRight - const Offset(12, 0));
        await tester.pump();
        expect(position(), greaterThan(.85));
        await drag.moveTo(bar.centerRight + const Offset(4, 0));
        await drag.up();
        await tester.pumpAndSettle();
        expect(position(), closeTo(1, .01));
        expect(find.text('#FF0000'), findsOneWidget);
      }

      expect(position(), closeTo(.5, .03));
      await moveToEnd();
      final spectrum = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ColorSpectrum',
      );
      await tester.ensureVisible(spectrum);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(spectrum));
      await tester.pumpAndSettle();
      expect(position(), closeTo(1, .01));
      final whiteSwatch = find.byWidgetPredicate((widget) {
        if (widget is! InkWell || widget.child is! Container) return false;
        final decoration = (widget.child! as Container).decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == Colors.white;
      });
      await tester.ensureVisible(whiteSwatch);
      await tester.pumpAndSettle();
      await tester.tap(whiteSwatch);
      await tester.pumpAndSettle();
      expect(find.text('#FFFFFF'), findsOneWidget);
      expect(position(), lessThan(.1));
      await tester.ensureVisible(find.text('Restaurar original'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar original'));
      await tester.pumpAndSettle();
      expect(find.text('#00FFFF'), findsOneWidget);
      expect(position(), closeTo(.5, .03));
      await moveToEnd();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(repo.folders[folder.id]?.color, 0xFFFF0000);
      expect(tester.takeException(), isNull);
    },
  );
}
