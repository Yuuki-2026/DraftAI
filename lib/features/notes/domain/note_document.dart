import 'dart:convert';

import 'entities.dart';

/// Portable document operations. Only attachment identifiers enter the document.
abstract final class NoteDocument {
  static const mediaKey = 'draftai-media';
  static const tableKey = 'draftai-table';

  /// Reads both the original attachment-id embed and resizable-image embeds.
  static String? mediaId(dynamic data) {
    if (data is! String || data.isEmpty) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['id'] is String) {
        return decoded['id'] as String;
      }
    } catch (_) {
      // Existing notes store the attachment id directly.
    }
    return data;
  }

  static double mediaWidth(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);
      final width = decoded is Map ? decoded['width'] : null;
      if (width is num) return width.toDouble().clamp(.2, 1).toDouble();
    } catch (_) {
      // Existing image embeds use the full available width.
    }
    return 1;
  }

  static String mediaAlignment(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);
      final alignment = decoded is Map ? decoded['alignment'] : null;
      if (alignment == 'left' || alignment == 'right') return alignment;
    } catch (_) {
      // Existing image embeds are centered by default.
    }
    return 'center';
  }

  static String mediaData(
    String id, {
    double width = 1,
    String alignment = 'center',
  }) => jsonEncode({
    'id': id,
    'width': width.clamp(.2, 1).toDouble(),
    'alignment': alignment == 'left' || alignment == 'right'
        ? alignment
        : 'center',
  });

  static List<List<String>> tableRows(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);
      if (decoded is! Map || decoded['rows'] is! List) return const [];
      return (decoded['rows'] as List)
          .take(12)
          .map(
            (row) => row is List
                ? row.take(6).map((cell) {
                    final text = cell.toString();
                    return text.length <= 500 ? text : text.substring(0, 500);
                  }).toList()
                : <String>[],
          )
          .where((row) => row.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String tableText(dynamic data) =>
      tableRows(data).map((row) => row.join(' | ')).join('\n');
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
        .map((o) => mediaId((o['insert'] as Map)[mediaKey]))
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
          .map((m) => mediaId(m[mediaKey]))
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
      final content = heading?.group(2) ?? bullet?.group(1) ?? line;
      final marks = RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__|\*([^*\n]+)\*');
      var cursor = 0;
      for (final match in marks.allMatches(content)) {
        if (match.start > cursor) {
          ops.add({'insert': content.substring(cursor, match.start)});
        }
        ops.add({
          'insert': match.group(1) ?? match.group(2) ?? match.group(3) ?? '',
          'attributes': {
            if (match.group(1) != null || match.group(2) != null)
              'bold': true
            else
              'italic': true,
          },
        });
        cursor = match.end;
      }
      if (cursor < content.length) {
        ops.add({'insert': content.substring(cursor)});
      }

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
        final id = mediaId(value[mediaKey]);
        if (id is String) {
          result.add(
            DocumentPart(
              attachmentId: id,
              imageWidth: mediaWidth(value[mediaKey]),
              imageAlignment: mediaAlignment(value[mediaKey]),
            ),
          );
        }
        final table = value[tableKey];
        if (table is String) {
          final plain = tableText(table);
          if (plain.isNotEmpty) result.add(DocumentPart(text: plain));
        }
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
    if (note.summary.isNotEmpty) {
      result.add(
        DocumentPart(
          text: note.summaryModel.isEmpty
              ? 'Resumen'
              : 'Resumen generado por IA',
          heading: 2,
        ),
      );
      if (note.summaryModel.isNotEmpty) {
        result.add(DocumentPart(text: note.summaryModel));
      }
      result.addAll(
        parts(
          note.copyWith(
            document: jsonEncode(formatted(note.summary)),
            documentVersion: 2,
            plainText: note.summary,
            summary: '',
            attachments: [],
          ),
        ),
      );
    }
    return result;
  }
}

class DocumentPart {
  final String text;
  final String? attachmentId;
  final int heading;
  final bool bullet;
  final double imageWidth;
  final String imageAlignment;
  const DocumentPart({
    this.text = '',
    this.attachmentId,
    this.heading = 0,
    this.bullet = false,
    this.imageWidth = 1,
    this.imageAlignment = 'center',
  });
}
