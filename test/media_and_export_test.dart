import 'dart:convert';

import 'package:flutter/services.dart';

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draft_ai/core/security/secure_store.dart';
import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/capture/data/local_media_repository.dart';
import 'package:draft_ai/features/export/data/document_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'media is encrypted on disk and exports are valid PDF and DOCX packages',
    () async {
      final root = await Directory.systemTemp.createTemp('draftai_export');
      try {
        final media = LocalMediaRepository(
          Directory('${root.path}/media'),
          root,
          await VaultCipher.open(MemorySecureStore()),
          () => 'test_image',
        );
        final bytes = (await rootBundle.load('assets/images/logo.png')).buffer
            .asUint8List();
        final attachment = await media.store(
          PickedFile('image.png', 'image/png', bytes),
        );
        expect(await media.read(attachment), bytes);
        expect(
          await File('${root.path}/media/test_image.bin').readAsBytes(),
          isNot(bytes),
        );
        await expectLater(
          media.read(const Attachment('../outside', 'bad.png', 'image/png')),
          throwsA(isA<AppFailure>()),
        );
        final now = DateTime.utc(2026, 10, 15);
        final note = Note(
          id: 'n',
          folderId: 'f',
          title: 'Cálculo & física <tema>',
          plainText: 'Primera línea.\nSegunda línea con acentos: áéíóú.',
          createdAt: now,
          updatedAt: now,
          attachments: [attachment],
        );
        final exporter = DocumentExport(media, root);
        final word = await exporter.buildWord([note]);
        final zip = ZipDecoder().decodeBytes(word);
        final xml = utf8.decode(
          zip.findFile('word/document.xml')!.content as List<int>,
        );
        expect(xml, contains('Cálculo &amp; física &lt;tema&gt;'));
        expect(xml, contains('cy="4643438"'));
        expect(zip.findFile('word/media/image1.png'), isNotNull);
        final pdf = await exporter.buildPdf([note]);
        expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
        final out = Directory('artifacts/test_exports');
        await out.create(recursive: true);
        await File('${out.path}/apunte.pdf').writeAsBytes(pdf);
        await File('${out.path}/apunte.docx').writeAsBytes(word);
        await media.delete(attachment);
        expect(await media.storageBytes(), 0);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
