import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/presentation/controller.dart';

class ExamplePage extends ConsumerStatefulWidget {
  const ExamplePage({super.key});
  @override
  ConsumerState<ExamplePage> createState() => _ExampleState();
}

class _ExampleState extends ConsumerState<ExamplePage> {
  bool busy = false;
  Future<void> _run(bool clear) async {
    if (busy) return;
    if (clear &&
        !await confirm(
          context,
          tr(context, 'Eliminar ejemplos'),
          tr(
            context,
            'Se eliminarán solo las notas de ejemplo, incluidos los cambios que les hayas hecho. Tus notas propias se conservan.',
          ),
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await runAction(context, () async {
      final service = ref.read(examplesPort);
      final count = clear ? await service.clear() : await service.load();
      if (mounted) {
        message(
          context,
          '$count ${tr(context, clear ? 'ejemplos eliminados' : 'ejemplos cargados')}',
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final has =
        ref
            .watch(libraryProvider)
            .value
            ?.notes
            .any((n) => n.id.startsWith('demo_')) ??
        false;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Biblioteca de prueba'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              Text(
                tr(
                  context,
                  'Carga 20 notas ficticias en 4 carpetas, con imágenes, PDF y textos para probar edición, lectura, IA y exportación. La instalación inicial permanece vacía hasta que lo solicites.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy || has ? null : () => _run(false),
                icon: const Icon(Icons.science_outlined),
                label: Text(tr(context, 'Cargar ejemplos')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy || !has ? null : () => _run(true),
                icon: const Icon(Icons.delete_outline),
                label: Text(tr(context, 'Eliminar ejemplos')),
              ),
              if (busy) const LinearProgressIndicator(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
