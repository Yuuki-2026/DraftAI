import 'dart:convert';
import 'dart:typed_data';

import 'package:draft_ai/features/notes/domain/entities.dart';
import 'package:draft_ai/features/notes/domain/ports.dart';
import 'package:draft_ai/features/notes/presentation/controller.dart';
import 'package:draft_ai/features/notes/presentation/media_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ImageMedia implements MediaRepository {
  @override
  Future<Uint8List> read(Attachment attachment) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAACgAAAAYCAIAAAAH5iiXAAAAKElEQVR4nGMIKJgwIIhh1OJRi0ctHrV41OJRi0ctHrV41OJRi4ePxQBOHew9RmApdgAAAABJRU5ErkJggg==',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final isLeft in [true, false]) {
    final side = isLeft ? 'izquierda' : 'derecha';
    testWidgets('La esquina inferior $side cambia el tamaño de la imagen', (
      tester,
    ) async {
      final committedWidths = <double>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaPort.overrideWithValue(_ImageMedia())],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: EmbeddedMedia(
                    attachment: const Attachment(
                      'image',
                      'imagen.png',
                      'image/png',
                    ),
                    editable: true,
                    widthFactor: .6,
                    onResize: committedWidths.add,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = find.byType(Image);
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(image).image,
          tester.element(image),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(image);
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      final handle = find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.child is GestureDetector &&
            widget.bottom != null &&
            (isLeft ? widget.left != null : widget.right != null),
      );
      final initialWidth = tester.getSize(image).width;
      final start = tester.getCenter(handle) + const Offset(0, 5);
      final direction = isLeft ? -1.0 : 1.0;
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(Offset(direction * 35, 0));
      await gesture.moveBy(Offset(direction * 60, 0));
      await tester.pump();
      expect(tester.getSize(image).width, greaterThan(initialWidth));
      expect(committedWidths, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(committedWidths.single, greaterThan(.6));
      expect(tester.takeException(), isNull);
    });
  }
}
