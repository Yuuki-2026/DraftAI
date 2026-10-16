import 'package:flutter/material.dart';

import 'strings.dart';

class PanelAction<T> {
  final T value;
  final String title, subtitle;
  final IconData icon;
  final String? badge;
  const PanelAction(
    this.value,
    this.title,
    this.subtitle,
    this.icon, {
    this.badge,
  });
}

Future<T?> showActionPanel<T>(
  BuildContext context, {
  required String title,
  required List<PanelAction<T>> actions,
  String? caption,
  bool choice = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: choice,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: Theme.of(context).dividerColor),
  ),
  builder: (c) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (caption != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  tr(c, caption),
                  style: Theme.of(c).textTheme.bodySmall!.copyWith(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: choice ? 18 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: tr(c, 'Cerrar'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Theme.of(c).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(c, a.value),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 34,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(c).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(a.icon, size: 17),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        tr(c, a.title),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (a.badge != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        a.badge!,
                                        style: Theme.of(c).textTheme.bodySmall!
                                            .copyWith(
                                              fontSize: 9,
                                              fontFamily: 'JetBrainsMono',
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  tr(c, a.subtitle),
                                  style: Theme.of(c).textTheme.bodySmall!
                                      .copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          if (choice)
                            const Icon(Icons.check_box_outline_blank, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (choice)
              OutlinedButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr(c, 'Cancelar')),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr(c, 'Toca el fondo para volver al apunte'),
                  textAlign: TextAlign.center,
                  style: Theme.of(c).textTheme.bodySmall!.copyWith(fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);
