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

class DocumentExport implements ConfigurableExportService {
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

  String _safeName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    final result = cleaned.isEmpty ? 'Apunte' : cleaned;
    return result.length > 72 ? result.substring(0, 72) : result;
  }

  String _attachmentName(String value) {
    final name = value
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[\r\n<>]'), '_');
    return name.isEmpty ? 'archivo' : name;
  }

  String _mathText(String source) {
    var value = source
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\;', ' ')
        .replaceAll(r'\quad', '  ')
        .replaceAll(r'\cdot', ' · ')
        .replaceAll(r'\times', ' × ')
        .replaceAll(r'\div', ' ÷ ')
        .replaceAll(r'\pm', ' ± ')
        .replaceAll(r'\leq', ' ≤ ')
        .replaceAll(r'\geq', ' ≥ ')
        .replaceAll(r'\neq', ' ≠ ')
        .replaceAll(r'\approx', ' ≈ ')
        .replaceAll(r'\rightarrow', ' → ')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\gamma', 'γ')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\sigma', 'σ')
        .replaceAll(r'\omega', 'ω')
        .replaceAll(r'\sum', 'Σ')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\sin', 'sin')
        .replaceAll(r'\cos', 'cos')
        .replaceAll(r'\tan', 'tan')
        .replaceAll(r'\log', 'log')
        .replaceAll(r'\ln', 'ln')
        .replaceAll(r'\lim', 'lim')
        .replaceAll(r'\max', 'max')
        .replaceAll(r'\min', 'min')
        .replaceAll(RegExp(r'\\(?:begin|end)\{[^}]+\}'), '')
        .replaceAll(r'\\\\', '; ')
        .replaceAll('&', ' ');
    value = value.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'),
      (match) => '(${match.group(1)})/(${match.group(2)})',
    );
    value = value.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]*)\}'),
      (match) => '√(${match.group(1)})',
    );
    value = value
        .replaceAllMapped(RegExp(r'\^\{([^{}]+)\}'), (m) => '^(${m[1]})')
        .replaceAllMapped(RegExp(r'_\{([^{}]+)\}'), (m) => '_(${m[1]})')
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll('\\', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value;
  }

  String _readableText(String source) {
    const formula =
        r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|(?<!\\)\$([^\n$]+?)(?<!\\)\$';
    final pattern = RegExp(formula);
    return source.replaceAllMapped(pattern, (match) {
      final tex =
          match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4)!;
      return _mathText(tex);
    });
  }

  Future<void> _shareFiles(List<(String, Uint8List, String)> files) async {
    final dir = Directory(p.join(cache.path, 'draftai_exports'));
    await dir.create(recursive: true);
    final exported = <XFile>[];
    for (final (name, bytes, mime) in files) {
      final file = File(p.join(dir.path, name));
      await file.writeAsBytes(bytes, flush: true);
      exported.add(XFile(file.path, mimeType: mime));
    }
    await SharePlus.instance.share(
      ShareParams(files: exported, subject: 'Apuntes de DraftAI'),
    );
  }

  @override
  Future<void> export(List<Note> notes, ExportFormat format) async {
    await exportConfigured(
      notes: notes,
      format: format,
      options: const ExportOptions(),
      separateFiles: false,
    );
  }

  @override
  Future<void> exportConfigured({
    required List<Note> notes,
    required ExportFormat format,
    required ExportOptions options,
    required bool separateFiles,
  }) async {
    if (notes.isEmpty) throw const AppFailure('Selecciona al menos un apunte.');
    final formatExtension = switch (format) {
      ExportFormat.pdf => 'pdf',
      ExportFormat.word => 'docx',
      ExportFormat.text => 'txt',
      ExportFormat.markdown => 'md',
    };
    final mime = switch (format) {
      ExportFormat.pdf => 'application/pdf',
      ExportFormat.word => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'text/plain',
    };
    final batches = separateFiles && notes.length > 1
        ? notes.map((note) => [note]).toList()
        : [notes];
    final shared = <(String, Uint8List, String)>[];
    final usedNames = <String, int>{};
    for (final batch in batches) {
      final title = batch.length == 1 ? batch.single.title : 'Apuntes';
      final base = _safeName(title);
      final occurrence = (usedNames[base] ?? 0) + 1;
      usedNames[base] = occurrence;
      final suffix = occurrence > 1 ? '-$occurrence' : '';
      final filename = '$base$suffix.$formatExtension';
      Uint8List bytes;
      if (format == ExportFormat.pdf) {
        bytes = await buildPdf(batch, options: options);
      } else if (format == ExportFormat.word) {
        bytes = await buildWord(batch, options: options);
      } else {
        bytes = Uint8List.fromList(
          utf8.encode(
            _plainDocument(batch, markdown: format == ExportFormat.markdown),
          ),
        );
      }
      shared.add((filename, bytes, mime));
    }
    if (shared.length == 1) {
      final (name, bytes, fileMime) = shared.single;
      await _share(name, bytes, fileMime);
    } else {
      await _shareFiles(shared);
    }
  }

  String _plainDocument(List<Note> notes, {required bool markdown}) {
    final documents = <String>[];
    for (final note in notes) {
      final out = StringBuffer();
      out.writeln('${markdown ? '# ' : ''}${_readableText(note.title)}');
      if (note.topic.trim().isNotEmpty) {
        out.writeln(
          '${markdown ? '**' : ''}${_readableText(note.topic)}${markdown ? '**' : ''}',
        );
      }
      out.writeln();
      for (final part in NoteDocument.parts(note)) {
        if (part.attachmentId != null) {
          final attachment = note.attachments
              .where((a) => a.id == part.attachmentId)
              .firstOrNull;
          if (attachment == null) continue;
          final filename = _attachmentName(attachment.name);
          if (attachment.mime.startsWith('image/')) {
            out.writeln('<< $filename >>');
          } else {
            out.writeln(
              '[${markdown ? 'Archivo adjunto' : 'Adjunto'}: $filename]',
            );
          }
          continue;
        }
        final heading = markdown && part.heading > 0
            ? '${'#' * part.heading} '
            : '';
        final bullet = part.bullet ? '- ' : '';
        out.writeln('$heading$bullet${_readableText(part.text)}');
      }
      documents.add(out.toString().trimRight());
    }
    return documents.join('\n\n${markdown ? '---' : '────────────────'}\n\n');
  }

  Future<(double, double)> _imageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return (frame.image.width.toDouble(), frame.image.height.toDouble());
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<Uint8List> buildPdf(
    List<Note> notes, {
    ExportOptions options = const ExportOptions(),
  }) async {
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
    final margin = options.pageMargin.clamp(18, 80).toDouble();
    final contentWidth = PdfPageFormat.a4.width - 2 * margin;
    for (final note in notes) {
      final content = <pw.Widget>[];
      for (final part in NoteDocument.parts(note)) {
        if (part.attachmentId != null) {
          final attachment = note.attachments
              .where((a) => a.id == part.attachmentId)
              .firstOrNull;
          if (attachment != null && attachment.mime.startsWith('image/')) {
            final bytes = await media.read(attachment);
            final (imageWidth, imageHeight) = await _imageSize(bytes);
            final factor = (part.imageWidth * options.imageScale)
                .clamp(.2, 1.6)
                .toDouble();
            final width = (contentWidth * factor)
                .clamp(80, contentWidth)
                .toDouble();
            final alignment = switch (part.imageAlignment) {
              'left' => pw.Alignment.centerLeft,
              'right' => pw.Alignment.centerRight,
              _ => pw.Alignment.center,
            };
            content.add(
              pw.Align(
                alignment: alignment,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Image(
                    pw.MemoryImage(bytes),
                    width: width,
                    height: (width * imageHeight / imageWidth)
                        .clamp(1, 640)
                        .toDouble(),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
          } else if (attachment != null) {
            content.add(
              pw.Paragraph(
                text:
                    '[${attachment.mime == 'application/pdf' ? 'PDF' : 'Archivo'}: ${_attachmentName(attachment.name)}]',
              ),
            );
          }
        } else if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(part.text.trim())) {
          content.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
              child: pw.Text(
                _readableText(part.text),
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          );
        } else if (part.heading > 0) {
          content.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 7, bottom: 4),
              child: pw.Text(
                _readableText(part.text),
                style: pw.TextStyle(
                  fontSize: (options.titleSize - part.heading * 3)
                      .clamp(11, 32)
                      .toDouble(),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
        } else {
          content.add(
            pw.Paragraph(
              text: '${part.bullet ? '• ' : ''}${_readableText(part.text)}',
              style: const pw.TextStyle(lineSpacing: 3),
            ),
          );
        }
      }
      final footerText = options.footer.trim();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          maxPages: 200,
          margin: pw.EdgeInsets.all(margin),
          header: options.includeDate
              ? (_) => pw.Text(
                  'DraftAI · ${note.createdAt.toLocal().toIso8601String().substring(0, 10)}',
                  style: const pw.TextStyle(fontSize: 9),
                )
              : null,
          footer: options.showPageNumbers || footerText.isNotEmpty
              ? (c) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (footerText.isNotEmpty)
                      pw.Expanded(
                        child: pw.Text(
                          footerText,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      )
                    else
                      pw.SizedBox(),
                    if (options.showPageNumbers)
                      pw.Text(
                        '${c.pageNumber} / ${c.pagesCount}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                )
              : null,
          build: (_) => [
            pw.Text(
              _readableText(note.title),
              style: pw.TextStyle(
                fontSize: options.titleSize.clamp(16, 36).toDouble(),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (note.topic.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 10),
                child: pw.Text(_readableText(note.topic)),
              ),
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

  Future<Uint8List> buildWord(
    List<Note> notes, {
    ExportOptions options = const ExportOptions(),
  }) async {
    final zip = Archive();
    final body = StringBuffer();
    final rels = StringBuffer();
    var imageId = 0;
    final widthEmu =
        ((PdfPageFormat.a4.width - 2 * options.pageMargin.clamp(18, 80)) *
                12700)
            .round();
    for (var noteIndex = 0; noteIndex < notes.length; noteIndex++) {
      final n = notes[noteIndex];
      final titleSize = (options.titleSize.clamp(16, 36) * 2).round();
      body.write(
        '<w:p><w:pPr><w:outlineLvl w:val="0"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="$titleSize"/></w:rPr><w:t>${_xml(_readableText(n.title))}</w:t></w:r></w:p>',
      );
      if (n.topic.isNotEmpty) {
        body.write(
          '<w:p><w:r><w:t>${_xml(_readableText(n.topic))}</w:t></w:r></w:p>',
        );
      }
      if (options.includeDate) {
        body.write(
          '<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${n.createdAt.toLocal().toIso8601String().substring(0, 10)}</w:t></w:r></w:p>',
        );
      }
      for (final part in NoteDocument.parts(n)) {
        if (part.attachmentId == null) {
          final text = _readableText('${part.bullet ? '• ' : ''}${part.text}');
          final headingSize =
              ((options.titleSize - part.heading * 3).clamp(11, 32) * 2)
                  .round();
          body.write(
            '<w:p>${part.heading > 0 ? '<w:pPr><w:outlineLvl w:val="${part.heading - 1}"/></w:pPr>' : ''}<w:r>${part.heading > 0 ? '<w:rPr><w:b/><w:sz w:val="$headingSize"/></w:rPr>' : ''}<w:t xml:space="preserve">${_xml(text)}</w:t></w:r></w:p>',
          );
          continue;
        }
        final a = n.attachments
            .where((a) => a.id == part.attachmentId)
            .firstOrNull;
        if (a == null) continue;
        if (!a.mime.startsWith('image/')) {
          body.write(
            '<w:p><w:r><w:t>${_xml('[Adjunto: ${_attachmentName(a.name)}]')}</w:t></w:r></w:p>',
          );
          continue;
        }
        imageId++;
        final paragraphAlignment = switch (part.imageAlignment) {
          'left' => 'left',
          'right' => 'right',
          _ => 'center',
        };
        var extension = a.mime == 'image/png' ? 'png' : 'jpg';
        var bytes = await media.read(a);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        var imageWidth =
            (widthEmu * (part.imageWidth * options.imageScale).clamp(.2, 1.6))
                .round()
                .clamp(1, widthEmu);
        var imageHeight = (imageWidth * frame.image.height / frame.image.width)
            .round();
        const maxImageHeight = 5943600;
        if (imageHeight > maxImageHeight) {
          imageWidth = (maxImageHeight * frame.image.width / frame.image.height)
              .round();
          imageHeight = maxImageHeight;
        }
        if (a.mime != 'image/png' && a.mime != 'image/jpeg') {
          final converted = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (converted == null)
            throw const AppFailure('No se pudo preparar una imagen para Word.');
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
          '<w:p><w:pPr><w:jc w:val="$paragraphAlignment"/></w:pPr><w:r><w:drawing><wp:inline><wp:extent cx="$imageWidth" cy="$imageHeight"/><wp:docPr id="$imageId" name="Imagen $imageId"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="$imageId" name="Imagen"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rId$imageId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$imageWidth" cy="$imageHeight"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>',
        );
      }
      if (noteIndex < notes.length - 1) {
        body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }
    final hasFooter =
        options.showPageNumbers || options.footer.trim().isNotEmpty;
    if (hasFooter) {
      rels.write(
        '<Relationship Id="rIdFooter1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>',
      );
      final footerText = _xml(options.footer.trim());
      final pageField = options.showPageNumbers
          ? '<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>'
          : '';
      _add(
        zip,
        'word/footer1.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>${footerText}</w:t></w:r>$pageField</w:p></w:ftr>',
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
      final marginEmu = (options.pageMargin.clamp(18, 80) * 12700).round();
      _add(
        zip,
        'word/document.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>$body<w:sectPr><w:footerReference w:type="default" r:id="rIdFooter1"/><w:pgMar w:top="$marginEmu" w:right="$marginEmu" w:bottom="$marginEmu" w:left="$marginEmu"/></w:sectPr></w:body></w:document>',
      );
      _add(
        zip,
        '[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpg" ContentType="image/jpeg"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/></Types>',
      );
      return Uint8List.fromList(ZipEncoder().encode(zip));
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
    final marginEmu = (options.pageMargin.clamp(18, 80) * 12700).round();
    _add(
      zip,
      'word/document.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>$body<w:sectPr><w:pgMar w:top="$marginEmu" w:right="$marginEmu" w:bottom="$marginEmu" w:left="$marginEmu"/></w:sectPr></w:body></w:document>',
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
