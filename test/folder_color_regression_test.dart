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

const _folder = Folder('f', 'Carpeta de prueba', 0xFF00FFFF);
final _slider = find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_HueSpectrumSlider',
);
final _marker = find.descendant(of: _slider, matching: find.byType(Positioned));

double _position(WidgetTester tester) {
  final track = tester.getRect(_slider);
  final thumb = tester.getRect(_marker);
  return (thumb.left - track.left) / (track.width - thumb.width);
}

Future<MemoryNotes> _openColorPicker(WidgetTester tester, double height) async {
  tester.view.physicalSize = Size(320, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = MemoryNotes();
  repo.folders[_folder.id] = _folder;
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
                  editFolder(context, ref, folder: _folder, colorOnly: true),
              child: const Text('Abrir selector'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir selector'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets(
    'El tono permanece en el extremo derecho hasta aplicar el color',
    (tester) async {
      final repo = await _openColorPicker(tester, 640);
      Future<void> moveToEnd() async {
        await tester.ensureVisible(_slider);
        await tester.pumpAndSettle();
        final bar = tester.getRect(_slider);
        final drag = await tester.startGesture(tester.getCenter(_marker));
        await drag.moveBy(const Offset(kPanSlop + 4, 0));
        await drag.moveTo(bar.centerRight - const Offset(12, 0));
        await tester.pump();
        expect(_position(tester), greaterThan(.85));
        await drag.moveTo(bar.centerRight + const Offset(4, 0));
        await drag.up();
        await tester.pumpAndSettle();
        expect(_position(tester), closeTo(1, .01));
        expect(find.text('#FF0000'), findsOneWidget);
      }

      expect(_position(tester), closeTo(.5, .03));
      await moveToEnd();
      final spectrum = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ColorSpectrum',
      );
      await tester.ensureVisible(spectrum);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(spectrum));
      await tester.pumpAndSettle();
      expect(_position(tester), closeTo(1, .01));
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
      expect(_position(tester), lessThan(.1));
      await tester.ensureVisible(find.text('Restaurar original'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar original'));
      await tester.pumpAndSettle();
      expect(find.text('#00FFFF'), findsOneWidget);
      expect(_position(tester), closeTo(.5, .03));
      await moveToEnd();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(repo.folders[_folder.id]?.color, 0xFFFF0000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'La barra sigue el arrastre horizontal y permite desplazar el diálogo',
    (tester) async {
      await _openColorPicker(tester, 480);
      await Scrollable.ensureVisible(tester.element(_slider), alignment: .5);
      await tester.pumpAndSettle();
      final scrollable = find.ancestor(
        of: _slider,
        matching: find.byType(Scrollable),
      );
      final scroll = tester.state<ScrollableState>(scrollable).position;
      final initialScroll = scroll.pixels;
      expect(scroll.maxScrollExtent, greaterThan(initialScroll));

      final drag = await tester.startGesture(tester.getCenter(_slider));
      await drag.moveBy(const Offset(22, -12));
      await tester.pump(const Duration(milliseconds: 60));
      await drag.moveBy(const Offset(2, -8));
      await tester.pump(const Duration(milliseconds: 60));
      await drag.moveBy(const Offset(40, -8));
      await drag.up();
      await tester.pumpAndSettle();
      final hueAfterDrag = _position(tester);
      expect(hueAfterDrag, greaterThan(.75));
      expect(scroll.pixels, initialScroll);

      final scrollGesture = await tester.startGesture(
        tester.getCenter(_slider),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await scrollGesture.moveBy(const Offset(0, -25));
      await tester.pump(const Duration(milliseconds: 60));
      await scrollGesture.moveBy(const Offset(0, -20));
      await scrollGesture.up();
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(initialScroll));
      expect(_position(tester), hueAfterDrag);

      await tester.ensureVisible(_slider);
      await tester.pumpAndSettle();
      final bar = tester.getRect(_slider);
      await tester.tapAt(Offset(bar.left + bar.width / 4, bar.center.dy));
      await tester.pumpAndSettle();
      expect(_position(tester), closeTo(.25, .01));
      expect(tester.takeException(), isNull);
    },
  );
}
