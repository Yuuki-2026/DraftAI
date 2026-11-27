import 'dart:convert';
import 'dart:io';

import 'package:draft_ai/core/security/secure_store.dart';
import 'package:draft_ai/features/capture/data/local_media_repository.dart';
import 'package:draft_ai/features/export/data/document_export.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF exports valid LaTeX as graphics and keeps invalid LaTeX as text',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'draftai_pdf_math',
      );
      addTearDown(() => directory.delete(recursive: true));
      final media = LocalMediaRepository(
        directory,
        directory,
        await VaultCipher.open(MemorySecureStore()),
        () => 'unused',
      );
      final exporter = DocumentExport(media, directory);
      final date = DateTime.utc(2026, 1, 1);
      final note = Note(
        id: 'note',
        folderId: 'folder',
        title: 'Cuaderno de matemáticas',
        createdAt: date,
        updatedAt: date,
      );
      final pdfImage = RegExp(r'/Subtype\s*/Image\b');

      for (final formula in [
        r'Antes \(\frac{1}{2}\) después.',
        r'\(x^{2}\)',
        r'\(\frac{1}{\sqrt{x}}\)',
        r'\[\frac{1}'
            '\n'
            r'{2}\]',
      ]) {
        final pdf = await exporter.buildPdf([
          note.copyWith(plainText: formula),
        ]);
        expect(latin1.decode(pdf), matches(pdfImage), reason: formula);
      }

      for (final text in ['Texto normal.', r'Antes \(\frac{1\) después.']) {
        final pdf = await exporter.buildPdf([note.copyWith(plainText: text)]);
        expect(latin1.decode(pdf), isNot(matches(pdfImage)), reason: text);
        expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
      }
    },
  );
}
