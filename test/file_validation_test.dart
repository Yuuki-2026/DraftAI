import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/capture/data/file_validation.dart';

void main() {
  test('renamed executable and incomplete PDF are rejected', () {
    for (final content in ['MZ executable', '%PDF-1.7 invalid']) {
      expect(
        () => FileValidation.validate(
          PickedFile(
            'file.pdf',
            'application/pdf',
            Uint8List.fromList(utf8.encode(content)),
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test('text validation rejects binary payload and incompatible extension', () {
    expect(
      () => FileValidation.validate(
        PickedFile('note.txt', 'text/plain', Uint8List.fromList([0, 1])),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => FileValidation.validate(
        PickedFile('note.exe', 'text/plain', Uint8List.fromList([65])),
      ),
      throwsA(isA<AppFailure>()),
    );
    FileValidation.validate(
      PickedFile(
        'note.md',
        'text/plain',
        Uint8List.fromList(utf8.encode('# Title')),
      ),
    );
  });
}
