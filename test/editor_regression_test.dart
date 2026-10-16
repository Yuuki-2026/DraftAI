import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/core/presentation/design.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/use_cases.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/notes/presentation/note_page.dart';

import 'support/memory_notes.dart';

Future<MemoryNotes> openEditor(WidgetTester tester, {bool edit = true}) async {
  tester.view.physicalSize = const Size(500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = MemoryNotes();
  repo.folders['f'] = const Folder('f', 'Clases', 0xFFFFFFFF);
  final note = Note(
    id: 'n',
    folderId: 'f',
    title: 'Sistemas operativos',
    plainText: 'Base',
    createdAt: DateTime(2026, 10, 15),
    updatedAt: DateTime(2026, 10, 15),
  );
  repo.notes['n'] = note;
  addTearDown(repo.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notesPort.overrideWithValue(repo),
        actionsPort.overrideWithValue(
          NoteActions(repo, DateTime.now, () => 'new'),
        ),
      ],
      child: MaterialApp(
        theme: appTheme(Brightness.light),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          q.FlutterQuillLocalizations.delegate,
        ],
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotePage(note: note, edit: edit),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets(
    'pasting then typing keeps editor stable and does not autosave; discard prompts',
    (tester) async {
      final repo = await openEditor(tester);
      final widget = tester.widget<q.QuillEditor>(find.byType(q.QuillEditor));
      final editor = widget.controller;
      widget.focusNode.requestFocus();
      await tester.pump();
      editor.replaceText(
        4,
        0,
        ' pegado',
        const TextSelection.collapsed(offset: 11),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        identical(
          tester.widget<q.QuillEditor>(find.byType(q.QuillEditor)).controller,
          editor,
        ),
        true,
      );
      expect(editor.document.toPlainText(), contains('Base pegado'));
      expect(tester.testTextInput.hasAnyClients, true);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Base pegado seguido\n',
          selection: TextSelection.collapsed(offset: 19),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(editor.document.toPlainText(), contains('seguido'));
      expect(repo.notes['n']!.plainText, 'Base');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('¿Guardar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir'), findsOneWidget);
      expect(repo.notes['n']!.plainText, 'Base');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets('save is explicit; back exits reading before leaving the note', (
    tester,
  ) async {
    final repo = await openEditor(tester);
    final editor = tester
        .widget<q.QuillEditor>(find.byType(q.QuillEditor))
        .controller;
    editor.replaceText(
      4,
      0,
      ' editado',
      const TextSelection.collapsed(offset: 12),
    );
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.notes['n']!.plainText, contains('Base editado'));
    expect(find.text('Cambios guardados.'), findsOneWidget);
    await tester.tap(find.text('Lectura').first);
    await tester.pumpAndSettle();
    expect(find.text('Modo lectura'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(NotePage), findsOneWidget);
    expect(find.text('Vista del apunte'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
    'add a topic inside the same note and save its date above the heading',
    (tester) async {
      final repo = await openEditor(tester);
      await tester.ensureVisible(find.text('Añadir tema'));
      await tester.tap(find.text('Añadir tema'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Gestión de señales');
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final saved = repo.notes['n']!;
      expect(saved.plainText, contains('Gestión de señales'));
      expect(repo.notes.length, 1);
      expect(saved.document, contains('"header":2'));
      expect(saved.document, contains('"header":3'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
