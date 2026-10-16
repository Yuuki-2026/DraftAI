import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;

import '../../../core/presentation/strings.dart';

/// Compact seven-control row from the editor mockup; additional formatting lives in Tipos.
class NoteFormatBar extends StatelessWidget {
  final q.QuillController controller;
  final VoidCallback onFormula;
  const NoteFormatBar({
    super.key,
    required this.controller,
    required this.onFormula,
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
        final active =
            controller.getSelectionStyle().attributes[attribute.key]?.value ==
            attribute.value;
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
              button(
                'Deshacer',
                const Icon(Icons.undo, size: 20),
                () => controller.undo(),
              ),
              button(
                'Rehacer',
                const Icon(Icons.redo, size: 20),
                () => controller.redo(),
              ),
            ],
          ),
          SizedBox(
            height: 42,
            child: q.QuillSimpleToolbar(
              controller: controller,
              config: const q.QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showDividers: false,
                showFontFamily: true,
                showFontSize: true,
                showBoldButton: false,
                showItalicButton: false,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showColorButton: true,
                showBackgroundColorButton: false,
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
              ),
            ),
          ),
        ],
      );
    },
  );
}
