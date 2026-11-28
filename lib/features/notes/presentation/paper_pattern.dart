import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const widePaperStyle = 'spaced';
const widePaperLineHeight = 2.5;
const _inlinePlaceholder = '\uFFFC';

class PaperPatternPainter extends CustomPainter {
  final String style;
  final Color color;
  final double scale;

  PaperPatternPainter({
    required this.style,
    required this.color,
    this.scale = 1,
  });

  bool get _ruled => style == 'lines' || style == widePaperStyle;

  @override
  void paint(Canvas canvas, Size size, {List<double> rows = const []}) {
    if (style == 'plain') return;
    final line = Paint()
      ..color = color.withValues(alpha: .22)
      ..strokeWidth = .8;
    final dot = Paint()
      ..color = color.withValues(alpha: .33)
      ..style = PaintingStyle.fill;

    final firstY = 19.0 * scale;
    final gap = (style == widePaperStyle ? 48.0 : 34.0) * scale;

    if (_ruled) {
      for (final y in rows) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
      final nextRow = rows.isEmpty ? firstY : rows.last + gap;
      for (var y = nextRow; y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    } else if (style == 'dots') {
      for (var y = firstY; y < size.height; y += gap) {
        for (var x = 17.0 * scale; x < size.width; x += gap) {
          canvas.drawCircle(Offset(x, y), 1, dot);
        }
      }
    } else {
      for (var x = 17.0 * scale; x < size.width; x += gap) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      }
      for (var y = firstY; y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperPatternPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.scale != scale;
}

class NotePaper extends SingleChildRenderObjectWidget {
  const NotePaper({super.key, required this.pattern, required super.child});

  final PaperPatternPainter pattern;

  @override
  RenderProxyBox createRenderObject(BuildContext context) =>
      _RenderNotePaper(pattern);

  @override
  void updateRenderObject(BuildContext context, RenderProxyBox renderObject) {
    (renderObject as _RenderNotePaper).pattern = pattern;
  }
}

class _RenderNotePaper extends RenderProxyBox {
  _RenderNotePaper(this._pattern);

  PaperPatternPainter _pattern;
  List<double>? _rows;

  set pattern(PaperPatternPainter value) {
    if (!value.shouldRepaint(_pattern)) return;
    _pattern = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    super.performLayout();
    _rows = null;
  }

  List<double> _textRows() {
    final rows = <double>{};

    void visit(RenderObject object) {
      if (object is RenderTable) return;
      if (object is! RenderParagraph) {
        object.visitChildren(visit);
        return;
      }
      if (!object.hasSize || object.size.isEmpty) return;
      final text = object.text.toPlainText(includeSemanticsLabels: false);
      if (text.replaceAll(_inlinePlaceholder, '').trim().isEmpty) return;
      final top = object.localToGlobal(Offset.zero, ancestor: this).dy;
      final selection = TextSelection(baseOffset: 0, extentOffset: text.length);
      final lineBoxes = object.getBoxesForSelection(
        selection,
        boxHeightStyle: BoxHeightStyle.max,
      );
      final glyphBoxes = object.getBoxesForSelection(selection);
      final lineBottoms = <double, double>{};
      // Group different text runs on the same line, then hug the glyphs.
      for (final (index, box) in lineBoxes.indexed) {
        final bottom = glyphBoxes.length == lineBoxes.length
            ? glyphBoxes[index].bottom
            : box.bottom;
        lineBottoms.update(
          box.bottom,
          (previous) => math.max(previous, bottom),
          ifAbsent: () => bottom,
        );
      }
      for (final bottom in lineBottoms.values) {
        final y = top + bottom + 1;
        if (y > 0 && y < size.height) rows.add(y);
      }
    }

    visitChildren(visit);
    return rows.toList()..sort();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // The rules and the text share this render box and its scroll position.
    final rows = _pattern._ruled ? (_rows ??= _textRows()) : const <double>[];
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _pattern.paint(canvas, size, rows: rows);
    canvas.restore();
    super.paint(context, offset);
  }
}
