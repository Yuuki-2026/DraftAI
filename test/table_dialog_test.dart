import 'package:draft_ai/core/presentation/design.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/note_document.dart';
import 'package:draft_ai/features/notes/domain/use_cases.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/notes/presentation/media_widgets.dart';
import 'package:draft_ai/features/notes/presentation/note_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_adapter_test.dart' show IdentityStub;
import 'support/memory_notes.dart';

final _dialog = find.byType(AlertDialog);
final _insert = find.descendant(
  of: _dialog,
  matching: find.widgetWithText(FilledButton, 'Insertar'),
);

Finder _cell(int row, int column) =>
    find.byKey(ValueKey('table-$row-$column-3-3'));

Future<MemoryNotes> _openEditor(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final date = DateTime(2026, 11, 27);
  final note = Note(
    id: 'n',
    folderId: 'f',
    title: 'Apunte de prueba',
    plainText: 'Antes después',
    createdAt: date,
    updatedAt: date,
  );
  final repo = MemoryNotes()
    ..folders['f'] = const Folder('f', 'Clases', 0xffffffff)
    ..notes['n'] = note;
  addTearDown(repo.close);
  var counter = 0;
  String newId() => 'test-${counter++}';
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notesPort.overrideWithValue(repo),
        identityPort.overrideWithValue(IdentityStub()),
        profileVaultPort.overrideWithValue(MemoryProfiles()),
        idPort.overrideWithValue(newId),
        actionsPort.overrideWithValue(NoteActions(repo, DateTime.now, newId)),
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
        home: NotePage(note: note, edit: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  for (final (size, keyboard) in [
    (const Size(360, 640), 290.0),
    (const Size(320, 480), 240.0),
  ]) {
    testWidgets(
      'las celdas y la confirmación son accesibles con teclado a $size',
      (tester) async {
        await _openEditor(tester, size);
        await tester.tap(find.byTooltip('Insertar tabla'));
        await tester.pumpAndSettle();
        await tester.enterText(_cell(0, 0), 'Materia');
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final lastCell = _cell(2, 2);
        await tester.ensureVisible(lastCell);
        await tester.pumpAndSettle();
        expect(lastCell.hitTestable(), findsOneWidget);
        await tester.enterText(lastCell, 'Física');
        await tester.pumpAndSettle();
        expect(_insert.hitTestable(), findsOneWidget);
        await tester.tap(_insert);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(_dialog, findsNothing);

        final tableFinder = find.byType(NoteTableView);
        final noteScroll = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          tableFinder,
          100,
          scrollable: noteScroll.first,
        );
        final table = tester.widget<NoteTableView>(tableFinder);
        final cells = NoteDocument.tableRows(table.data);
        expect(cells.first.first, 'Materia');
        expect(cells.last.last, 'Física');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'al insertar desde Tipos, la tabla queda visible y se puede guardar',
    (tester) async {
      final repo = await _openEditor(tester, const Size(390, 812));
      final editor = tester
          .widget<q.QuillEditor>(find.byType(q.QuillEditor))
          .controller;
      editor.updateSelection(
        const TextSelection.collapsed(offset: 6),
        q.ChangeSource.local,
      );
      await tester.tap(find.text('Tipos'));
      await tester.pumpAndSettle();
      final action = find.widgetWithText(OutlinedButton, 'Insertar tabla');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      expect(find.text('Tipos y formato', skipOffstage: false), findsNothing);

      await tester.enterText(_cell(0, 0), 'Matemáticas');
      await tester.tap(_insert);
      await tester.pumpAndSettle();
      expect(find.text('Matemáticas').hitTestable(), findsOneWidget);
      final delta = editor.document.toDelta().toJson();
      expect(delta.first['insert'], 'Antes \n');
      expect(delta.last['insert'], '\ndespués\n');

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.notes['n']!.document, contains('Matemáticas'));
      expect(tester.takeException(), isNull);
    },
  );
}
