import 'dart:convert';

import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/presentation/note_reader.dart';
import 'package:draft_ai/features/notes/presentation/paper_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('El lector conserva la alineación con cada estilo de página', (
    tester,
  ) async {
    const paragraphs = [
      ('Párrafo centrado', 'center', TextAlign.center),
      ('Párrafo a la izquierda', 'left', TextAlign.left),
      ('Párrafo a la derecha', 'right', TextAlign.right),
      ('Párrafo justificado', 'justify', TextAlign.justify),
    ];
    final date = DateTime(2026, 11, 25);
    final note = Note(
      id: 'n',
      folderId: 'f',
      title: 'Alineación',
      createdAt: date,
      updatedAt: date,
      document: jsonEncode([
        for (final (text, align, _) in paragraphs) ...[
          {'insert': text},
          {
            'insert': '\n',
            'attributes': {'align': align},
          },
        ],
      ]),
    );
    for (final style in ['plain', 'lines', 'grid', 'dots', 'spaced']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: PaperPatternPainter(style: style, color: Colors.black),
              child: NoteReader(note: note),
            ),
          ),
        ),
      );
      for (final (text, _, expected) in paragraphs) {
        expect(
          tester
              .widget<RichText>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is RichText && widget.text.toPlainText() == text,
                ),
              )
              .textAlign,
          expected,
          reason: '$style: $text',
        );
      }
    }
  });
}
