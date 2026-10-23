import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as color_picker;
import 'package:flutter_quill/flutter_quill.dart' as q;

import '../../../core/presentation/strings.dart';

typedef PersistentColorChanged = void Function(bool isBackground, String? hex);

/// Compact seven-control row from the editor mockup; additional formatting lives in Tipos.
class NoteFormatBar extends StatelessWidget {
  final q.QuillController controller;
  final VoidCallback onFormula;
  final VoidCallback onDismissKeyboard;
  final PersistentColorChanged onPersistentColorChanged;
  const NoteFormatBar({
    super.key,
    required this.controller,
    required this.onFormula,
    required this.onDismissKeyboard,
    required this.onPersistentColorChanged,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      Widget button(
        String label,
        Widget child,
        VoidCallback action, {
        q.Attribute? attribute,
      }) {
        final active =
            attribute != null &&
            controller.getSelectionStyle().attributes[attribute.key]?.value ==
                attribute.value;
        return Expanded(
          child: Tooltip(
            message: tr(context, label),
            child: InkWell(
              onTap: action,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: active
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: child,
              ),
            ),
          ),
        );
      }

      void toggle(q.Attribute attribute) {
        final selection = controller.selection;
        final active =
            controller.getSelectionStyle().attributes[attribute.key]?.value ==
            attribute.value;
        onDismissKeyboard();
        controller.updateSelection(selection, q.ChangeSource.local);
        controller.formatSelection(
          active ? q.Attribute.clone(attribute, null) : attribute,
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              button(
                'Negrita',
                const Text('B', style: TextStyle(fontWeight: FontWeight.w700)),
                () => toggle(q.Attribute.bold),
                attribute: q.Attribute.bold,
              ),
              button(
                'Cursiva',
                const Text('I', style: TextStyle(fontStyle: FontStyle.italic)),
                () => toggle(q.Attribute.italic),
                attribute: q.Attribute.italic,
              ),
              button(
                'Encabezado',
                const Text('H1', style: TextStyle(fontSize: 12)),
                () => toggle(q.Attribute.h1),
                attribute: q.Attribute.h1,
              ),
              button(
                'Lista',
                const Icon(Icons.format_list_bulleted, size: 18),
                () => toggle(q.Attribute.ul),
                attribute: q.Attribute.ul,
              ),
              button(
                'Fórmula',
                const Text('ƒx', style: TextStyle(fontStyle: FontStyle.italic)),
                onFormula,
              ),
              button('Deshacer', const Icon(Icons.undo, size: 20), () {
                onDismissKeyboard();
                controller.undo();
              }),
              button('Rehacer', const Icon(Icons.redo, size: 20), () {
                onDismissKeyboard();
                controller.redo();
              }),
            ],
          ),
          SizedBox(
            height: 42,
            child: q.QuillSimpleToolbar(
              controller: controller,
              config: q.QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showDividers: false,
                showFontFamily: true,
                showFontSize: true,
                showBoldButton: false,
                showItalicButton: false,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showClearFormat: true,
                showHeaderStyle: false,
                showListNumbers: false,
                showListBullets: false,
                showListCheck: false,
                showCodeBlock: false,
                showInlineCode: false,
                showQuote: false,
                showIndent: false,
                showLink: false,
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                buttonOptions: q.QuillSimpleToolbarButtonOptions(
                  base: q.QuillToolbarBaseButtonOptions(
                    afterButtonPressed: onDismissKeyboard,
                  ),
                  color: noteTextColorButtonOptions(
                    context,
                    onDismissKeyboard,
                    onPersistentColorChanged,
                  ),
                  backgroundColor: noteHighlightButtonOptions(
                    context,
                    onDismissKeyboard,
                    onPersistentColorChanged,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

q.QuillToolbarColorButtonOptions noteTextColorButtonOptions(
  BuildContext context,
  VoidCallback onDismissKeyboard,
  PersistentColorChanged onPersistentColorChanged,
) => q.QuillToolbarColorButtonOptions(
  iconData: Icons.palette_outlined,
  tooltip: tr(context, 'Color de texto'),
  customOnPressedCallback: (controller, isBackground) =>
      showSelectionColorPicker(
        context: context,
        controller: controller,
        isBackground: isBackground,
        onDismissKeyboard: onDismissKeyboard,
        onPersistentColorChanged: onPersistentColorChanged,
      ),
);

q.QuillToolbarColorButtonOptions noteHighlightButtonOptions(
  BuildContext context,
  VoidCallback onDismissKeyboard,
  PersistentColorChanged onPersistentColorChanged,
) => q.QuillToolbarColorButtonOptions(
  iconData: Icons.border_color,
  tooltip: tr(context, 'Resaltador'),
  customOnPressedCallback: (controller, isBackground) =>
      showSelectionColorPicker(
        context: context,
        controller: controller,
        isBackground: isBackground,
        onDismissKeyboard: onDismissKeyboard,
        onPersistentColorChanged: onPersistentColorChanged,
      ),
);

Future<void> showSelectionColorPicker({
  required BuildContext context,
  required q.QuillController controller,
  required bool isBackground,
  required VoidCallback onDismissKeyboard,
  required PersistentColorChanged onPersistentColorChanged,
}) async {
  final selection = controller.selection;
  final attribute = isBackground ? q.Attribute.background : q.Attribute.color;
  final current = controller
      .getSelectionStyle()
      .attributes[attribute.key]
      ?.value;
  final initial =
      _parseColor(current) ??
      (isBackground ? const Color(0xFFFFEB3B) : Colors.black);
  onDismissKeyboard();
  final result = await showDialog<_ColorPickerResult>(
    context: context,
    builder: (dialogContext) => _SelectionColorPickerDialog(
      isBackground: isBackground,
      initialColor: initial,
    ),
  );
  if (result == null || !context.mounted) return;
  controller.updateSelection(selection, q.ChangeSource.local);
  String? selectedHex;
  if (result.clear) {
    controller.formatSelection(
      isBackground
          ? const q.BackgroundAttribute(null)
          : const q.ColorAttribute(null),
    );
  } else {
    final hex = color_picker.colorToHex(
      result.color!,
      includeHashSign: true,
      enableAlpha: false,
    );
    selectedHex = hex;
    controller.formatSelection(
      isBackground ? q.BackgroundAttribute(hex) : q.ColorAttribute(hex),
    );
  }
  onPersistentColorChanged(isBackground, selectedHex);
  onDismissKeyboard();
}

Color? _parseColor(Object? value) {
  if (value is! String) return null;
  final hex = value.trim().replaceFirst('#', '');
  if (hex.length != 6 && hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}

class SelectionColorButton extends StatelessWidget {
  final q.QuillController controller;
  final bool isBackground;
  final VoidCallback onDismissKeyboard;
  final PersistentColorChanged? onPersistentColorChanged;

  const SelectionColorButton({
    super.key,
    required this.controller,
    required this.isBackground,
    required this.onDismissKeyboard,
    this.onPersistentColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = tr(context, isBackground ? 'Resaltador' : 'Color de texto');
    final action = () => showSelectionColorPicker(
      context: context,
      controller: controller,
      isBackground: isBackground,
      onDismissKeyboard: onDismissKeyboard,
      onPersistentColorChanged: onPersistentColorChanged ?? (_, __) {},
    );
    if (isBackground) {
      return IconButton(
        tooltip: label,
        onPressed: action,
        icon: const Icon(Icons.border_color, size: 20),
      );
    }
    return IconButton(
      tooltip: label,
      onPressed: action,
      icon: const Icon(Icons.palette_outlined, size: 20),
    );
  }
}

class _ColorPickerResult {
  final Color? color;
  final bool clear;
  const _ColorPickerResult.color(this.color) : clear = false;
  const _ColorPickerResult.clear() : color = null, clear = true;
}

enum _ColorPickerTab { material, custom }

class _SelectionColorPickerDialog extends StatefulWidget {
  final bool isBackground;
  final Color initialColor;
  const _SelectionColorPickerDialog({
    required this.isBackground,
    required this.initialColor,
  });

  @override
  State<_SelectionColorPickerDialog> createState() =>
      _SelectionColorPickerDialogState();
}

class _SelectionColorPickerDialogState
    extends State<_SelectionColorPickerDialog> {
  static const _materialColors = <Color>[
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

  late Color selectedColor;
  late final TextEditingController hexController;
  _ColorPickerTab tab = _ColorPickerTab.material;

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor;
    hexController = TextEditingController(
      text: color_picker.colorToHex(
        selectedColor,
        includeHashSign: true,
        enableAlpha: false,
      ),
    );
  }

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  void _select(Color color) {
    setState(() {
      selectedColor = color;
      hexController.text = color_picker.colorToHex(
        color,
        includeHashSign: true,
        enableAlpha: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 64)
        .clamp(250.0, 340.0)
        .toDouble();
    final title = tr(
      context,
      widget.isBackground ? 'Color de resaltado' : 'Selecciona un color',
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  _pickerTab(context, _ColorPickerTab.material, 'Material'),
                  _pickerTab(context, _ColorPickerTab.custom, 'Color'),
                ],
              ),
              const SizedBox(height: 8),
              if (tab == _ColorPickerTab.material)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _materialColors.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisExtent: 42,
                  ),
                  itemBuilder: (context, index) {
                    final color = _materialColors[index];
                    return Center(
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _select(color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == selectedColor
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                              width: color == selectedColor ? 2 : 1,
                            ),
                          ),
                          child: color == selectedColor
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color:
                                      ThemeData.estimateBrightnessForColor(
                                            color,
                                          ) ==
                                          Brightness.light
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                )
              else
                color_picker.ColorPicker(
                  pickerColor: selectedColor,
                  onColorChanged: _select,
                  colorPickerWidth: width,
                  pickerAreaHeightPercent: .55,
                  enableAlpha: false,
                  labelTypes: const [],
                  displayThumbColor: true,
                  paletteType: color_picker.PaletteType.hsvWithHue,
                  pickerAreaBorderRadius: BorderRadius.circular(10),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: hexController,
                maxLength: 7,
                onChanged: (value) {
                  final parsed = _parseColor(value);
                  if (parsed != null) setState(() => selectedColor = parsed);
                },
                decoration: InputDecoration(
                  labelText: tr(context, 'HEX'),
                  prefixIcon: const Icon(Icons.tag),
                  counterText: '',
                  border: const OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, const _ColorPickerResult.clear()),
                  icon: const Icon(Icons.format_color_reset),
                  label: Text(
                    tr(
                      context,
                      widget.isBackground ? 'Sin relleno' : 'Sin color',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr(context, 'Cancelar')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _ColorPickerResult.color(selectedColor),
                    ),
                    child: Text(tr(context, 'Aplicar')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerTab(BuildContext context, _ColorPickerTab value, String label) {
    final selected = tab == value;
    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => tab = value),
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          tr(context, label),
          style: TextStyle(fontWeight: selected ? FontWeight.w700 : null),
        ),
      ),
    );
  }
}
