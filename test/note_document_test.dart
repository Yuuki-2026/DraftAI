import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/note_document.dart';

void main() {
  Note sample(String document) => Note(
    id: 'n',
    folderId: 'f',
    title: 'T',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    plainText: 'Texto',
    document: document,
    attachments: const [Attachment('a', 'private.jpg', 'image/jpeg')],
  );
  test(
    'legacy attachment is inserted exactly once without filename or path',
    () {
      final migrated = NoteDocument.delta(sample(''));
      expect(NoteDocument.references(jsonEncode(migrated)), {'a'});
      expect(jsonEncode(migrated), isNot(contains('private.jpg')));
      expect(NoteDocument.delta(sample(jsonEncode(migrated))), migrated);
    },
  );
  test('document preserves text-image-text order and heading attributes', () {
    final note = sample(
      jsonEncode([
        {'insert': 'Before\n'},
        {
          'insert': {'draftai-media': 'a'},
        },
        {'insert': '\n'},
        {'insert': 'After'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
      ]),
    );
    final parts = NoteDocument.parts(note);
    expect(parts.map((p) => p.attachmentId ?? p.text), [
      'Before',
      'a',
      'After',
    ]);
    expect(parts.last.heading, 1);
    expect(NoteDocument.formatted('# Title\n- Item')[1]['attributes'], {
      'header': 1,
    });
  });
}
