import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

import '../../notes/domain/entities.dart';
import '../../notes/domain/note_document.dart';
import '../../notes/domain/ports.dart';
import '../../notes/data/note_mapper.dart';

class DocumentExport implements ExportService {
  final MediaRepository media;
  final Directory cache;
  DocumentExport(this.media, this.cache);
  Future<void> _share(String name, List<int> bytes, String mime) async {
    final dir = Directory(p.join(cache.path, 'draftai_exports'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        subject: 'Apuntes de DraftAI',
      ),
    );
  }

  @override
  Future<void> export(List<Note> notes, ExportFormat format) async {
    if (notes.isEmpty) throw const AppFailure('Selecciona al menos un apunte.');
    final rawName = notes.length == 1
        ? notes.first.title.replaceAll(RegExp(r'[^\wáéíóúñÁÉÍÓÚÑ -]'), '_')
        : 'Apuntes';
    final name = rawName.length > 80 ? rawName.substring(0, 80) : rawName;
    if (format == ExportFormat.pdf) {
      await _share('$name.pdf', await buildPdf(notes), 'application/pdf');
    } else if (format == ExportFormat.word) {
      await _share(
        '$name.docx',
        await buildWord(notes),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } else {
      final markdown = format == ExportFormat.markdown;
      final text = notes
          .map(
            (n) =>
                '${markdown ? '# ' : ''}${n.title}\n${n.topic}\n\n${NoteDocument.parts(n).map((p) => p.attachmentId != null ? '[Adjunto]' : '${markdown && p.heading > 0 ? '#' * p.heading + ' ' : ''}${p.bullet ? '- ' : ''}${p.text}').join('\n')}',
          )
          .join('\n\n---\n\n');
      await _share(
        '$name.${markdown ? 'md' : 'txt'}',
        utf8.encode(text),
        'text/plain',
      );
    }
  }

  Future<Uint8List> buildPdf(List<Note> notes) async {
    final data = await rootBundle.load('assets/fonts/Inter.ttf');
    final font = pw.Font.ttf(data);
    final math = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansMath.ttf'),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: [math],
      ),
    );
    for (final note in notes) {
      final content = <pw.Widget>[];
      for (final part in NoteDocument.parts(note)) {
        if (part.attachmentId != null) {
          final a = note.attachments
              .where((a) => a.id == part.attachmentId)
              .firstOrNull;
          if (a != null && a.mime.startsWith('image/')) {
            content.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Image(
                  pw.MemoryImage(await media.read(a)),
                  height: 200,
                  fit: pw.BoxFit.contain,
                ),
              ),
            );
          } else if (a != null) {
            content.add(
              pw.Paragraph(
                text: a.mime == 'application/pdf' ? '[PDF]' : '[Documento]',
              ),
            );
          }
        } else if (part.heading > 0) {
          content.add(pw.Header(level: part.heading, text: part.text));
        } else {
          content.add(
            pw.Paragraph(text: '${part.bullet ? '• ' : ''}${part.text}'),
          );
        }
      }
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          maxPages: 200,
          margin: const pw.EdgeInsets.all(36),
          header: (_) => pw.Text(
            'DraftAI · ${note.createdAt.toLocal().toIso8601String().substring(0, 10)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          footer: (c) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${c.pageNumber} / ${c.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (_) => [
            pw.Header(level: 0, text: note.title),
            if (note.topic.isNotEmpty) pw.Paragraph(text: note.topic),
            ...content,
          ],
        ),
      );
    }

    return doc.save();
  }

  String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  void _add(Archive a, String name, String value) {
    final b = utf8.encode(value);
    a.addFile(ArchiveFile(name, b.length, b));
  }

  Future<Uint8List> buildWord(List<Note> notes) async {
    final zip = Archive();
    final body = StringBuffer();
    final rels = StringBuffer();
    var imageId = 0;
    for (final n in notes) {
      body.write(
        '<w:p><w:pPr><w:outlineLvl w:val="0"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="36"/></w:rPr><w:t>${_xml(n.title)}</w:t></w:r></w:p>',
      );
      if (n.topic.isNotEmpty) {
        body.write('<w:p><w:r><w:t>${_xml(n.topic)}</w:t></w:r></w:p>');
      }
      for (final part in NoteDocument.parts(n)) {
        if (part.attachmentId == null) {
          body.write(
            '<w:p>${part.heading > 0 ? '<w:pPr><w:outlineLvl w:val="${part.heading - 1}"/></w:pPr>' : ''}<w:r>${part.heading > 0 ? '<w:rPr><w:b/><w:sz w:val="${32 - part.heading * 2}"/></w:rPr>' : ''}<w:t xml:space="preserve">${_xml('${part.bullet ? '• ' : ''}${part.text}')}</w:t></w:r></w:p>',
          );
          continue;
        }
        final a = n.attachments
            .where((a) => a.id == part.attachmentId)
            .firstOrNull;
        if (a == null) continue;
        if (!a.mime.startsWith('image/')) {
          body.write('<w:p><w:r><w:t>[Documento adjunto]</w:t></w:r></w:p>');
          continue;
        }
        imageId++;
        var extension = a.mime == 'image/png' ? 'png' : 'jpg';
        var bytes = await media.read(a);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final imageHeight = (4572000 * frame.image.height / frame.image.width)
            .round();
        if (a.mime != 'image/png' && a.mime != 'image/jpeg') {
          final converted = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (converted == null) {
            throw const AppFailure('No se pudo preparar una imagen para Word.');
          }
          bytes = converted.buffer.asUint8List();
          extension = 'png';
        }
        frame.image.dispose();
        codec.dispose();
        zip.addFile(
          ArchiveFile(
            'word/media/image$imageId.$extension',
            bytes.length,
            bytes,
          ),
        );
        rels.write(
          '<Relationship Id="rId$imageId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image$imageId.$extension"/>',
        );
        body.write(
          '<w:p><w:r><w:drawing><wp:inline><wp:extent cx="4572000" cy="$imageHeight"/><wp:docPr id="$imageId" name="Imagen $imageId"/>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="$imageId" name="Imagen"/><pic:cNvPicPr/></pic:nvPicPr>'
          '<pic:blipFill><a:blip r:embed="rId$imageId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="4572000" cy="$imageHeight"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>',
        );
      }
    }
    _add(
      zip,
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpg" ContentType="image/jpeg"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
    );
    _add(
      zip,
      '_rels/.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
    );
    _add(
      zip,
      'word/_rels/document.xml.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$rels</Relationships>',
    );
    _add(
      zip,
      'word/document.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>$body<w:sectPr/></w:body></w:document>',
    );
    return Uint8List.fromList(ZipEncoder().encode(zip));
  }

  @override
  Future<void> backup(Library library) async {
    final zip = Archive();
    _add(
      zip,
      'library.json',
      jsonEncode({
        'version': 1,
        'folders': library.folders
            .map((f) => {'id': f.id, 'name': f.name, 'color': f.color})
            .toList(),
        'categories': library.categories
            .map((c) => {'id': c.id, 'folderId': c.folderId, 'name': c.name})
            .toList(),
        'notes': library.notes
            .map((n) => jsonDecode(NoteMapper.encode(n)))
            .toList(),
      }),
    );
    for (final n in library.notes) {
      for (final a in n.attachments) {
        final b = await media.read(a);
        zip.addFile(ArchiveFile('attachments/${a.id}', b.length, b));
      }
    }
    await _share(
      'DraftAI-copia.zip',
      ZipEncoder().encode(zip),
      'application/zip',
    );
  }
}
