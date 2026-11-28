import 'dart:convert';

import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/note_document.dart';
import 'package:draft_ai/features/notes/presentation/media_widgets.dart';
import 'package:draft_ai/features/notes/presentation/note_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_test/flutter_test.dart';

Future<void> _openNote(WidgetTester tester, List<Object?> operations) async {
  final date = DateTime(2026, 11, 27);
  final note = Note(
    id: 'note',
    folderId: 'folder',
    title: 'Potencias',
    createdAt: date,
    updatedAt: date,
    document: jsonEncode(operations),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NoteReader(note: note)),
    ),
  );
}

Finder _richText(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == text,
);

void main() {
  testWidgets('el lector renderiza fórmulas partidas por cambios de formato', (
    tester,
  ) async {
    const before = 'Calcula ';
    const partial = r'\(x^2 + 1\)';
    const whole = r'\(\frac{1}{2}\)';
    const after = ' al final.';
    const text = '$before$partial y $whole$after';
    final editor = q.QuillController(
      document: q.Document.fromJson([
        {'insert': '$text\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(editor.dispose);
    editor.formatText(before.length + 2, 1, q.Attribute.bold);
    editor.formatText(text.indexOf(whole), whole.length, q.Attribute.bold);
    editor.formatText(0, before.length, q.Attribute.italic);
    editor.formatText(
      text.indexOf(after),
      after.length,
      const q.ColorAttribute('#9B265A'),
    );

    await _openNote(tester, editor.document.toDelta().toJson());

    final formulas = tester.widgetList<Math>(find.byType(Math)).toList();
    expect(formulas, hasLength(2));
    expect(formulas.first.textStyle?.fontWeight, FontWeight.normal);
    expect(formulas.last.textStyle?.fontWeight, FontWeight.bold);
    const renderedText = '$before\uFFFC y \uFFFC$after';
    final paragraph = tester.widget<RichText>(_richText(renderedText));
    expect(
      paragraph.text
          .getSpanForPosition(const TextPosition(offset: 1))
          ?.style
          ?.fontStyle,
      FontStyle.italic,
    );
    expect(
      paragraph.text
          .getSpanForPosition(
            TextPosition(offset: renderedText.indexOf(after) + 1),
          )
          ?.style
          ?.color,
      const Color(0xff9b265a),
    );
  });

  testWidgets(
    'el lector conserva el código y su formato si la fórmula es inválida',
    (tester) async {
      const start = r'\(\frac{';
      const end = r'\)';
      const source = '${start}1$end';
      await _openNote(tester, [
        {'insert': start},
        {
          'insert': '1',
          'attributes': {'bold': true},
        },
        {'insert': '$end\n'},
      ]);

      final text = tester.widget<RichText>(_richText(source));
      expect(
        text.text
            .getSpanForPosition(TextPosition(offset: start.length))
            ?.style
            ?.fontWeight,
        FontWeight.bold,
      );
    },
  );

  testWidgets('los delimitadores separados por una tabla se leen como texto', (
    tester,
  ) async {
    const start = r'Antes \(x';
    const end = r'^2\) después';
    await _openNote(tester, [
      {'insert': start},
      {
        'insert': {
          NoteDocument.tableKey: jsonEncode({
            'id': 'table',
            'rows': [
              ['Materia'],
            ],
          }),
        },
      },
      {'insert': '$end\n'},
    ]);

    expect(find.byType(NoteTableView), findsOneWidget);
    expect(_richText(start), findsOneWidget);
    expect(_richText(end), findsOneWidget);
    expect(find.byType(Math), findsNothing);
  });
}
