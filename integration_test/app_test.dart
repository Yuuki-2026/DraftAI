import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:draft_ai/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('guest creates, edits and reopens a local note', (tester) async {
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
    await tester.enterText(
      find.byKey(const Key('note-title')),
      'Prueba de persistencia',
    );
    final editor = tester.widget<q.QuillEditor>(find.byType(q.QuillEditor));
    editor.controller.document.insert(0, 'Contenido guardado en Android.');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar').first);
    await tester.pumpAndSettle();
    expect(find.text('Prueba de persistencia'), findsWidgets);
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Papelera'));
    await tester.pumpAndSettle();
    expect(find.text('Prueba de persistencia'), findsWidgets);
    await tester.tap(find.text('Restaurar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver Plan Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-pro')));
    await tester.pumpAndSettle();
    expect(find.text('Pro · demostración'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
