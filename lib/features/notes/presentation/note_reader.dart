import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../domain/entities.dart';
import '../domain/note_document.dart';
import 'media_widgets.dart';

final noteMathPattern = RegExp(
  r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|(?<!\\)\$([^\n$]+?)(?<!\\)\$',
);

/// TeX display never changes the editor's offsets or original source.
class NoteMathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const NoteMathText(this.text, {super.key, this.style});
  static List<InlineSpan> spans(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in noteMathPattern.allMatches(text)) {
      if (m.start > cursor)
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      final tex = m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4)!;
      if (tex.length > 1500) {
        spans.add(TextSpan(text: m.group(0)));
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.sizeOf(context).width - 88).clamp(
                  120.0,
                  640.0,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Math.tex(
                    tex,
                    mathStyle: m.group(1) != null || m.group(2) != null
                        ? MathStyle.display
                        : MathStyle.text,
                    textStyle: style.copyWith(height: 1.2),
                    onErrorFallback: (_) => Text(m.group(0)!, style: style),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        Theme.of(context).textTheme.bodyMedium!
            .copyWith(fontSize: 15, height: 1.65);
    return Text.rich(
      TextSpan(style: base, children: spans(context, text, base)),
    );
  }
}

class _ReadLine {
  final List<Map<String, dynamic>> runs;
  final Map attributes;
  const _ReadLine(this.runs, this.attributes);
  String get text =>
      runs.map((o) => o['insert'] is String ? o['insert'] : '').join();
}

class NoteReader extends StatelessWidget {
  final Note note;
  const NoteReader({super.key, required this.note});
  List<_ReadLine> _lines() {
    final lines = <_ReadLine>[], runs = <Map<String, dynamic>>[];
    for (final op in NoteDocument.delta(note)) {
      if (op['insert'] is! String) {
        runs.add(op);
        continue;
      }
      final pieces = (op['insert'] as String).split('\n');
      for (var i = 0; i < pieces.length; i++) {
        if (pieces[i].isNotEmpty) runs.add({...op, 'insert': pieces[i]});
        if (i < pieces.length - 1) {
          lines.add(
            _ReadLine(List.of(runs), op['attributes'] as Map? ?? const {}),
          );
          runs.clear();
        }
      }
    }
    if (runs.isNotEmpty) lines.add(_ReadLine(runs, const {}));
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme, lines = _lines();
    final blocks = <Widget>[];
    var ordered = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var text = line.text;
      final trim = text.trim();
      final delimiter = trim.startsWith(r'$$')
          ? r'$$'
          : trim.startsWith(r'\[')
          ? r'\]'
          : null;
      if (delimiter != null &&
          (trim == r'$$' ||
              trim == r'\[' ||
              !trim.substring(2).contains(delimiter))) {
        var end = i;
        while (end + 1 < lines.length && end - i < 30) {
          end++;
          text += '\n${lines[end].text}';
          if (lines[end].text.contains(delimiter)) break;
        }
        if (text.substring(2).contains(delimiter)) {
          blocks.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: NoteMathText(text),
            ),
          );
          i = end;
          continue;
        }
      }
      final date = RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(trim);
      final heading = line.attributes['header'] as int? ?? 0;
      final base = TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: date
            ? 11
            : heading == 1
            ? 23
            : heading == 2
            ? 19
            : heading > 0
            ? 17
            : 15,
        height: date ? 1.4 : 1.65,
        color: date ? scheme.onSurfaceVariant : scheme.onSurface,
        fontWeight: !date && heading > 0 ? FontWeight.w600 : FontWeight.normal,
      );
      ordered = line.attributes['list'] == 'ordered' ? ordered + 1 : 0;
      final spans = <InlineSpan>[
        if (line.attributes['list'] == 'bullet') const TextSpan(text: '• '),
        if (line.attributes['list'] == 'ordered') TextSpan(text: '$ordered. '),
      ];
      for (final op in line.runs) {
        final value = op['insert'];
        if (value is Map) {
          final a = note.attachments
              .where(
                (a) =>
                    a.id == NoteDocument.mediaId(value[NoteDocument.mediaKey]),
              )
              .firstOrNull;
          if (a != null) {
            if (spans.isNotEmpty) {
              blocks.add(
                Text.rich(TextSpan(style: base, children: List.of(spans))),
              );
              spans.clear();
            }
            blocks.add(
              EmbeddedMedia(
                attachment: a,
                gallery: note.attachments,
                widthFactor: NoteDocument.mediaWidth(
                  value[NoteDocument.mediaKey],
                ),
                alignment: NoteDocument.mediaAlignment(
                  value[NoteDocument.mediaKey],
                ),
              ),
            );
          }
          final tableData = value[NoteDocument.tableKey];
          if (tableData is String) {
            if (spans.isNotEmpty) {
              blocks.add(
                Text.rich(TextSpan(style: base, children: List.of(spans))),
              );
              spans.clear();
            }
            blocks.add(NoteTableView(data: tableData));
          }
          continue;
        }
        final attrs = op['attributes'] as Map? ?? const {};
        Color? color;
        Color? backgroundColor;
        final raw = attrs['color'];
        final rawBackground = attrs['background'];
        if (!date &&
            raw is String &&
            RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(raw))
          color = Color(int.parse('FF${raw.substring(1)}', radix: 16));
        if (!date &&
            rawBackground is String &&
            RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(rawBackground)) {
          backgroundColor = Color(
            int.parse('FF${rawBackground.substring(1)}', radix: 16),
          );
        }
        final style = base.copyWith(
          fontSize: date
              ? 11
              : double.tryParse(attrs['size']?.toString() ?? '') ??
                    base.fontSize,
          fontFamily: attrs['font'] as String? ?? base.fontFamily,
          fontWeight: attrs['bold'] == true ? FontWeight.bold : base.fontWeight,
          fontStyle: attrs['italic'] == true
              ? FontStyle.italic
              : FontStyle.normal,
          color: color,
          backgroundColor: backgroundColor,
          decoration: TextDecoration.combine([
            if (attrs['underline'] == true) TextDecoration.underline,
            if (attrs['strike'] == true) TextDecoration.lineThrough,
          ]),
        );
        spans.add(
          TextSpan(
            style: style,
            children: NoteMathText.spans(context, value as String, style),
          ),
        );
      }
      if (spans.isNotEmpty || line.runs.isEmpty)
        blocks.add(
          Padding(
            padding: EdgeInsets.only(
              top: date
                  ? 8
                  : heading > 0
                  ? 10
                  : 2,
              bottom: date ? 2 : 8,
            ),
            child: spans.isEmpty
                ? const SizedBox(height: 5)
                : Text.rich(TextSpan(style: base, children: spans)),
          ),
        );
    }
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: blocks,
      ),
    );
  }
}
