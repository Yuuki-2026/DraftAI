import 'note_reader.dart';

import 'package:flutter/material.dart';

import '../domain/note_document.dart';

class RichAiText extends StatelessWidget {
  final String text;
  const RichAiText(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final paragraphs = <Widget>[], spans = <InlineSpan>[];
    for (final op in NoteDocument.formatted(text)) {
      final value = op['insert'] as String;
      final attrs = op['attributes'] as Map? ?? const {};
      if (value == '\n') {
        final heading = attrs['header'] as int? ?? 0;
        paragraphs.add(
          Padding(
            padding: EdgeInsets.only(top: heading > 0 ? 10 : 2, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  if (attrs['list'] == 'bullet') const TextSpan(text: '• '),
                  ...spans,
                ],
              ),
              style: TextStyle(
                fontSize: heading == 1
                    ? 21
                    : heading == 2
                    ? 17
                    : heading == 3
                    ? 15
                    : 13,
                fontWeight: heading > 0 ? FontWeight.w600 : FontWeight.normal,
                height: 1.6,
              ),
            ),
          ),
        );
        spans.clear();
      } else {
        spans.add(
          TextSpan(
            children: NoteMathText.spans(
              context,
              value,
              Theme.of(context).textTheme.bodyMedium!
                  .copyWith(fontSize: 14, height: 1.65),
            ),
            style: TextStyle(
              fontWeight: attrs['bold'] == true ? FontWeight.w700 : null,
              fontStyle: attrs['italic'] == true ? FontStyle.italic : null,
            ),
          ),
        );
      }
    }
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: paragraphs,
      ),
    );
  }
}
