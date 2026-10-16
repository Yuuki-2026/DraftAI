import 'dart:convert';

import 'entities.dart';

/// Portable document operations. Only attachment identifiers enter the document.
abstract final class NoteDocument {
  static const mediaKey = 'draftai-media';
  static List<Map<String, dynamic>> delta(Note note) {
    List<Map<String, dynamic>> ops;
    try {
      ops = (jsonDecode(note.document) as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      if (ops.isEmpty || ops.any((v) => !v.containsKey('insert'))) {
        throw const FormatException();
      }
    } catch (_) {
      ops = [
        {'insert': '${note.plainText}\n'},
      ];
    }
    if (ops.last['insert'] is! String ||
        !(ops.last['insert'] as String).endsWith('\n')) {
      ops.add({'insert': '\n'});
    }
    final used = ops
        .where((o) => o['insert'] is Map)
        .map((o) => (o['insert'] as Map)[mediaKey])
        .whereType<String>()
        .toSet();
    // Legacy notes stored their media outside the document. Append them once.
    for (final a in note.attachments.where(
      (a) =>
          (note.documentVersion < 2 || note.document.isEmpty) &&
          !used.contains(a.id),
    )) {
      ops.add({
        'insert': {mediaKey: a.id},
      });
      ops.add({'insert': '\n'});
    }
    return ops;
  }

  static Set<String> references(String document) {
    try {
      return (jsonDecode(document) as List)
          .whereType<Map>()
          .map((o) => o['insert'])
          .whereType<Map>()
          .map((m) => m[mediaKey])
          .whereType<String>()
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static List<Map<String, dynamic>> formatted(String text) {
    final ops = <Map<String, dynamic>>[];
    for (final line in text.replaceAll('\r\n', '\n').split('\n')) {
      final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*•]\s+(.+)$').firstMatch(line);
      ops.add({'insert': heading?.group(2) ?? bullet?.group(1) ?? line});
      ops.add({
        'insert': '\n',
        if (heading != null)
          'attributes': {'header': heading.group(1)!.length}
        else if (bullet != null)
          'attributes': {'list': 'bullet'},
      });
    }
    return ops;
  }

  static List<DocumentPart> parts(Note note) {
    final result = <DocumentPart>[];
    var text = '';
    for (final op in delta(note)) {
      final value = op['insert'];
      if (value is Map) {
        if (text.isNotEmpty) {
          result.add(DocumentPart(text: text));
          text = '';
        }
        final id = value[mediaKey];
        if (id is String) result.add(DocumentPart(attachmentId: id));
      } else if (value is String) {
        final lines = value.split('\n');
        for (var i = 0; i < lines.length; i++) {
          text += lines[i];
          if (i < lines.length - 1) {
            final attrs = op['attributes'] is Map
                ? op['attributes'] as Map
                : const {};
            if (text.isNotEmpty) {
              result.add(
                DocumentPart(
                  text: text,
                  heading: attrs['header'] is int ? attrs['header'] as int : 0,
                  bullet: attrs['list'] == 'bullet',
                ),
              );
            }
            text = '';
          }
        }
      }
    }
    if (text.isNotEmpty) result.add(DocumentPart(text: text));
    return result;
  }
}

class DocumentPart {
  final String text;
  final String? attachmentId;
  final int heading;
  final bool bullet;
  const DocumentPart({
    this.text = '',
    this.attachmentId,
    this.heading = 0,
    this.bullet = false,
  });
}
