import 'package:draft_ai/features/notes/presentation/note_format_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('text color bar preserves dragged hue from black', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = q.QuillController.basic();
    addTearDown(controller.dispose);
    controller.document.insert(0, 'Texto');
    const selection = TextSelection(baseOffset: 0, extentOffset: 5);
    controller.updateSelection(selection, q.ChangeSource.local);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionColorButton(
            controller: controller,
            isBackground: false,
            onDismissKeyboard: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Color'));
    await tester.pumpAndSettle();

    final slider = find.byType(ColorPickerSlider);
    final bounds = tester.getRect(slider);
    double hue() => tester.widget<ColorPickerSlider>(slider).hsvColor.hue;

    expect(hue(), 0);
    final drag = await tester.startGesture(
      bounds.centerLeft + const Offset(16, 0),
    );
    await drag.moveBy(const Offset(25, 0));
    await drag.moveTo(bounds.center);
    await tester.pump();
    expect(hue(), closeTo(180, 5));
    await drag.moveTo(bounds.centerRight - const Offset(18, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(hue(), greaterThan(345));

    await tester.tapAt(bounds.center);
    await tester.pumpAndSettle();
    final pickedHue = hue();
    final area = tester.getRect(find.byType(ColorPickerArea));
    await tester.tapAt(area.topRight + const Offset(-20, 20));
    await tester.pumpAndSettle();
    final hex = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    final appliedColor = Color(
      0xFF000000 | int.parse(hex.substring(1), radix: 16),
    );
    expect(HSVColor.fromColor(appliedColor).hue, closeTo(pickedHue, 2));

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(controller.selection, selection);
    final color = controller
        .getSelectionStyle()
        .attributes[q.Attribute.color.key];
    expect((color?.value as String).toLowerCase(), hex.toLowerCase());
  });
}
