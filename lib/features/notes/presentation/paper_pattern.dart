import 'package:flutter/material.dart';

class PaperPatternPainter extends CustomPainter {
  final String style;
  final Color color;
  final double scale;
  final ScrollController? scrollController;

  PaperPatternPainter({
    required this.style,
    required this.color,
    this.scale = 1,
    this.scrollController,
  }) : super(repaint: scrollController);

  @override
  void paint(Canvas canvas, Size size) {
    if (style == 'plain') return;
    final line = Paint()
      ..color = color.withValues(alpha: .15)
      ..strokeWidth = .8;
    final dot = Paint()
      ..color = color.withValues(alpha: .22)
      ..style = PaintingStyle.fill;

    final offset = scrollController?.hasClients == true
        ? scrollController!.offset
        : 0.0;
    double firstY(double gap) {
      var y = 19.0 * scale - offset % gap;
      while (y < 0) {
        y += gap;
      }
      return y;
    }

    if (style == 'lines' || style == 'spaced') {
      final gap = (style == 'spaced' ? 48.0 : 34.0) * scale;
      for (var y = firstY(gap); y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
      return;
    }

    if (style == 'dots') {
      final gap = 34.0 * scale;
      for (var y = firstY(gap); y < size.height; y += gap) {
        for (var x = 17.0 * scale; x < size.width; x += gap) {
          canvas.drawCircle(Offset(x, y), 1 * scale, dot);
        }
      }
      return;
    }

    final gap = 34.0 * scale;
    for (var x = 17.0 * scale; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = firstY(gap); y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant PaperPatternPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.scale != scale ||
      oldDelegate.scrollController != scrollController;
}
