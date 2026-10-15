import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:draft_ai/main.dart' as app;

Future<void> waitUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('La interfaz no alcanzó el estado esperado.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('guest creates, edits and reopens a local note', (tester) async {
    // Mock only the keyboard channel; Android storage, encryption and plugins stay real.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    await app.main();
    await tester.pumpAndSettle();
    if (find.byKey(const Key('guest-enter')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('guest-enter')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('new-note')));
    await tester.pumpAndSettle();
    if (find.text('¿Dónde guardar la nota?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Mis apuntes').first);
      await tester.pumpAndSettle();
    }
    await waitUntil(
      tester,
      () => find.byKey(const Key('note-title')).evaluate().isNotEmpty,
    );
    await tester.enterText(
      find.byKey(const Key('note-title')),
      'Prueba de persistencia',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-title')))
          .controller!
          .text,
      'Prueba de persistencia',
    );
    final editor = tester.widget<q.QuillEditor>(find.byType(q.QuillEditor));
    editor.controller.document.insert(0, 'Contenido guardado en Android.');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar').first);
    await waitUntil(
      tester,
      () => tester
          .widget<q.QuillEditor>(find.byType(q.QuillEditor))
          .controller
          .readOnly,
    );
    final titleFinder = find.byWidgetPredicate(
      (w) => w is SelectableText && w.data == 'Prueba de persistencia',
    );
    await tester.scrollUntilVisible(
      titleFinder,
      -250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'Prueba de persistencia',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Prueba de persistencia'), findsWidgets);
    await tester.tap(find.text('Prueba de persistencia').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<q.QuillEditor>(find.byType(q.QuillEditor))
          .controller
          .document
          .toPlainText(),
      contains('Contenido guardado en Android.'),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar a la papelera'));
    await waitUntil(
      tester,
      () => find.byKey(const Key('new-note')).evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Papelera'));
    await tester.pumpAndSettle();
    expect(find.text('Prueba de persistencia'), findsWidgets);
    await tester.tap(find.text('Restaurar').first);
    await waitUntil(
      tester,
      () => find.text('Tu papelera está vacía').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir perfil'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Ver Plan Pro').evaluate().isNotEmpty
          ? find.text('Ver Plan Pro')
          : find.text('Plan Pro demostrativo'),
    );
    await tester.pumpAndSettle();
    if (find.text('Activar vista previa de Pro').evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('toggle-pro')));
    }
    await waitUntil(
      tester,
      () => find.text('Pro · demostración').evaluate().isNotEmpty,
    );
    expect(find.text('Pro · demostración'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
