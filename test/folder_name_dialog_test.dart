import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/folder_names.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/notes/presentation/library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_notes.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('crear, renombrar y crear apunte avisan del nombre duplicado', (
    tester,
  ) async {
    const existing = Folder('f', 'Ciencias Sociales', 0xffffffff);
    const other = Folder('o', 'Otra carpeta', 0xffffffff);
    final repo = MemoryNotes()
      ..folders[existing.id] = existing
      ..folders[other.id] = other;
    addTearDown(repo.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notesPort.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(libraryProvider);
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => editFolder(context, ref),
                      child: const Text('Crear carpeta de prueba'),
                    ),
                    TextButton(
                      onPressed: () => editFolder(context, ref, folder: other),
                      child: const Text('Renombrar carpeta de prueba'),
                    ),
                    TextButton(
                      onPressed: () => createNote(context, ref),
                      child: const Text('Abrir formulario de apunte'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final folderName = _field('Nombre de la carpeta');
    const duplicate = ' CIENCIAS  SOCIALES ';
    final duplicateWarning = find.text(FolderNames.duplicateMessage);
    final save = find.widgetWithText(FilledButton, 'Guardar');
    for (final (action, validName) in [
      ('Crear carpeta de prueba', 'Nombre disponible'),
      ('Renombrar carpeta de prueba', other.name),
    ]) {
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.enterText(folderName, duplicate);
      await tester.pumpAndSettle();
      expect(duplicateWarning, findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(folderName, validName);
      await tester.pumpAndSettle();
      expect(duplicateWarning, findsNothing);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Abrir formulario de apunte'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Título del apunte'), 'Apunte de prueba');
    await tester.tap(find.text('Nueva carpeta'));
    await tester.pumpAndSettle();
    await tester.enterText(folderName, duplicate);
    await tester.pumpAndSettle();
    expect(duplicateWarning, findsOneWidget);
    final create = find.ancestor(
      of: find.text('Crear apunte'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(folderName, 'Nombre disponible');
    await tester.pumpAndSettle();
    expect(duplicateWarning, findsNothing);
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.folders.keys, unorderedEquals(['f', 'o']));
    expect(tester.takeException(), isNull);
  });
}
