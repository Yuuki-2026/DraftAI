import 'dart:convert';

import 'entities.dart';
import 'note_document.dart';

class NoteSection {
  final String id, title;
  final DateTime date;
  final List<Map<String, dynamic>> operations;
  const NoteSection(this.id, this.title, this.date, this.operations);
  String get text => operations
      .map((o) => o['insert'] is String ? o['insert'] : '')
      .join()
      .trim();
}

/// Topics are standard document headings. Dates travel with the document in
/// storage and exports; legacy content keeps its original creation date.
abstract final class NoteSections {
  static String label(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static DateTime? _date(String s) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s.trim());
    if (m == null) return null;
    final d = DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    return label(d) == s.trim() ? d : null;
  }

  static List<List<Map<String, dynamic>>> _lines(Note n) {
    final lines = <List<Map<String, dynamic>>>[],
        line = <Map<String, dynamic>>[];
    for (final op in NoteDocument.delta(n)) {
      final value = op['insert'];
      if (value is! String) {
        line.add(op);
        continue;
      }
      final pieces = value.split('\n');
      for (var i = 0; i < pieces.length; i++) {
        if (pieces[i].isNotEmpty) line.add({...op, 'insert': pieces[i]});
        if (i < pieces.length - 1) {
          line.add({...op, 'insert': '\n'});
          lines.add(List.of(line));
          line.clear();
        }
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  static String _text(List<Map<String, dynamic>> line) =>
      line.map((o) => o['insert'] is String ? o['insert'] : '').join().trim();
  static bool _heading(List<Map<String, dynamic>> line) =>
      [1, 2].contains((line.last['attributes'] as Map?)?['header']);
  static List<NoteSection> read(Note n) {
    final lines = _lines(n), result = <NoteSection>[];
    var ops = <Map<String, dynamic>>[],
        title = n.topic.isEmpty ? n.title : n.topic;
    var date = n.createdAt.toLocal();
    void finish() {
      if (ops.any(
        (o) => o['insert'] is Map || (o['insert'] as String).trim().isNotEmpty,
      )) {
        result.add(
          NoteSection('${n.id}:${result.length}', title, date, List.of(ops)),
        );
      }
      ops = [];
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final stamp = (line.last['attributes'] as Map?)?['header'] == 3
          ? _date(_text(line))
          : null;
      if (stamp != null && i + 1 < lines.length && _heading(lines[i + 1])) {
        finish();
        date = stamp;
        title = _text(lines[++i]);
        ops.addAll(lines[i]);
      } else if (_heading(line)) {
        finish();
        date = n.createdAt.toLocal();
        title = _text(line);
        ops.addAll(line);
      } else {
        ops.addAll(line);
      }
    }
    finish();
    return result;
  }

  static Note stamp(Note current, Note? previous, DateTime now) {
    final old = previous == null ? <NoteSection>[] : read(previous);
    final fresh = read(current), out = <Map<String, dynamic>>[];
    final counts = <String, int>{};
    for (final section in fresh) {
      final occurrence = counts.update(
        section.title,
        (v) => v + 1,
        ifAbsent: () => 0,
      );
      final matches = old.where((s) => s.title == section.title).toList();
      final before = occurrence < matches.length ? matches[occurrence] : null;
      final unchanged =
          before != null &&
          jsonEncode(before.operations) == jsonEncode(section.operations);
      final date = unchanged ? before.date : now.toLocal();
      out.add({'insert': label(date)});
      out.add({
        'insert': '\n',
        'attributes': {'header': 3},
      });
      final hasHeading = section.operations.any(
        (o) => [1, 2].contains((o['attributes'] as Map?)?['header']),
      );
      if (!hasHeading) {
        out.add({'insert': section.title});
        out.add({
          'insert': '\n',
          'attributes': {'header': 2},
        });
      }
      out.addAll(section.operations);
    }
    if (out.isEmpty) return current;
    return current.copyWith(
      document: jsonEncode(out),
      documentVersion: 2,
      plainText: out
          .map((o) => o['insert'] is String ? o['insert'] as String : '')
          .join()
          .trimRight(),
    );
  }

  static Note? select(
    Note note, {
    Set<String>? topics,
    DateTime? from,
    DateTime? until,
  }) {
    final chosen = read(note).where((s) {
      if (topics != null && !topics.contains(s.id)) return false;
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      return (from == null ||
              !day.isBefore(DateTime(from.year, from.month, from.day))) &&
          (until == null ||
              day.isBefore(DateTime(until.year, until.month, until.day + 1)));
    }).toList();
    if (chosen.isEmpty) return null;
    return note.copyWith(
      plainText: chosen.map((s) => '${label(s.date)}\n${s.text}').join('\n\n'),
    );
  }
}
