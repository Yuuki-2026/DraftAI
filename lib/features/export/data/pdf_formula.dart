import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pdf/widgets.dart' as pw;

const _formulaPixelRatio = 4.0;

class _FormulaRenderView extends RenderView {
  _FormulaRenderView({required super.view, required super.child})
    : super(
        configuration: const ViewConfiguration(
          logicalConstraints: BoxConstraints(),
        ),
      );

  double? baseline;

  @override
  void performLayout() {
    super.performLayout();
    baseline = child?.getDistanceToBaseline(TextBaseline.alphabetic);
  }
}

Future<pw.WidgetSpan?> renderPdfFormula(
  String tex, {
  required bool display,
  required double fontSize,
  required double maxWidth,
}) async {
  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  if (view == null) return null;

  final boundary = RenderRepaintBoundary();
  final renderView = _FormulaRenderView(view: view, child: boundary);
  final pipeline = PipelineOwner()..rootNode = renderView;
  final focus = FocusManager();
  final owner = BuildOwner(focusManager: focus);
  renderView.prepareInitialFrame();
  // Lay out the formula locally without adding a widget to the app's screen.
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Math.tex(
          tex,
          mathStyle: display ? MathStyle.display : MathStyle.text,
          textStyle: TextStyle(
            inherit: false,
            color: const Color(0xff000000),
            fontSize: fontSize,
          ),
          onErrorFallback: (_) => const SizedBox.shrink(),
        ),
      ),
    ),
  ).attachToRenderTree(owner);

  try {
    owner.buildScope(root);
    pipeline.flushLayout();
    final size = boundary.size;
    if (size.isEmpty) return null;
    pipeline.flushCompositingBits();
    pipeline.flushPaint();

    // Fit oversized formulas on A4 while keeping their proportions.
    final scale = math.min(1.0, maxWidth / size.longestSide);
    final descent = size.height - (renderView.baseline ?? size.height);
    final image = await boundary.toImage(
      pixelRatio: scale * _formulaPixelRatio,
    );
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return pw.WidgetSpan(
        baseline: -descent * scale,
        child: pw.Image(
          pw.MemoryImage(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          ),
          width: size.width * scale,
          height: size.height * scale,
        ),
      );
    } finally {
      image.dispose();
    }
  } finally {
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
        .attachToRenderTree(owner, root);
    owner.buildScope(root);
    owner.finalizeTree();
    pipeline.rootNode = null;
    renderView.child = null;
    boundary.dispose();
    renderView.dispose();
    focus.dispose();
    pipeline.dispose();
  }
}
