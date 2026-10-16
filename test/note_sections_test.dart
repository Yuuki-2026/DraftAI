import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/note_document.dart';
import 'package:draft_ai/features/notes/domain/note_sections.dart';

Note example(String content) => Note(
  id: 'os',
  folderId: 'f',
  title: 'Sistemas operativos',
  document: jsonEncode(NoteDocument.formatted(content)),
  plainText: content,
  createdAt: DateTime(2026, 10, 15),
  updatedAt: DateTime(2026, 10, 15),
);

void main() {
  test('same-day edits keep one date per topic, later edits touch only changed topic', () {
    final first = NoteSections.stamp(
      example('## Memoria\nPaginación\n## Señales\nEventos'),
      null,
      DateTime(2026, 10, 15),
    );
    final same = NoteSections.stamp(
      first.copyWith(
        document: first.document.replaceAll('Paginación', 'Paginación virtual'),
      ),
      first,
      DateTime(2026, 10, 15, 18),
    );
    expect(NoteSections.read(same).length, 2);
    expect(NoteSections.read(same).map((s) => s.date.day), [15, 15]);
    expect('15/10/2026'.allMatches(same.plainText).length, 2);
    final later = NoteSections.stamp(
      same.copyWith(
        document: same.document.replaceAll('Eventos', 'Eventos y señales'),
      ),
      same,
      DateTime(2026, 10, 16),
    );
    final topics = NoteSections.read(later);
    expect(topics.map((s) => s.date.day), [15, 16]);
    expect(topics.map((s) => s.title), ['Memoria', 'Señales']);
    final unchanged = NoteSections.stamp(later, later, DateTime(2026, 10, 17));
    expect(unchanged.document, later.document);
  });
  test('topic and date filters intersect and never include another topic', () {
    final note = NoteSections.stamp(
      example('## Memoria\nPáginas\n## Señales\nEventos'),
      null,
      DateTime(2026, 10, 15),
    );
    final parts = NoteSections.read(note);
    final selected = NoteSections.select(
      note,
      topics: {parts.first.id},
      from: DateTime(2026, 10, 15),
      until: DateTime(2026, 10, 15),
    );
    expect(selected!.plainText, contains('Páginas'));
    expect(selected.plainText, isNot(contains('Eventos')));
    expect(
      NoteSections.select(note, topics: {}, from: DateTime(2026, 10, 15)),
      isNull,
    );
    expect(
      NoteSections.select(
        note,
        topics: {parts.first.id},
        from: DateTime(2026, 10, 16),
      ),
      isNull,
    );
  });
  test(
    'legacy dates survive summary-only save and attachments preserve order',
    () {
      final legacy = example('Contenido');
      final stamped = NoteSections.stamp(
        legacy.copyWith(summary: 'Resumen'),
        legacy,
        DateTime(2026, 10, 16),
      );
      expect(NoteSections.read(stamped).single.date.day, 15);
      final withMedia = example('## Memoria\nTexto').copyWith(
        document: jsonEncode([
          ...NoteDocument.formatted('## Memoria\nTexto'),
          {
            'insert': {NoteDocument.mediaKey: 'photo'},
          },
          {'insert': '\n'},
        ]),
      );
      final result = NoteSections.stamp(
        withMedia,
        null,
        DateTime(2026, 10, 16),
      );
      expect(NoteDocument.references(result.document), {'photo'});
      expect(
        result.document.indexOf('Texto'),
        lessThan(result.document.indexOf('photo')),
      );
    },
  );
}
