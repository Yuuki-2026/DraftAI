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
    if (style == 'lines' || style == 'spaced') {
      final gap = (style == 'spaced' ? 36.0 : 26.0) * scale;
      for (var y = (gap - offset % gap); y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
      return;
    }

    if (style == 'dots') {
      final gap = 26.0 * scale;
      for (var y = (gap - offset % gap); y < size.height; y += gap) {
        for (var x = gap; x < size.width; x += gap) {
          canvas.drawCircle(Offset(x, y), 1 * scale, dot);
        }
      }
      return;
    }

    final gap = 26.0 * scale;
    for (var x = gap; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = (gap - offset % gap); y < size.height; y += gap) {
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
