import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/use_cases.dart';
import '../../notes/presentation/controller.dart';

class AiPage extends ConsumerStatefulWidget {
  final List<Note> initialNotes;
  final Future<void> Function(String)? onInsert;
  const AiPage({super.key, this.initialNotes = const [], this.onInsert});
  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  final selected = <String>{};
  DateTime? from, until;
  bool byDates = false, external = false, busy = false;
  String instruction = 'Genera un mapa mental en Markdown y Mermaid.',
      result = '';
  @override
  void initState() {
    super.initState();
    selected.addAll(widget.initialNotes.map((n) => n.id));
  }

  Future<void> _date(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: (start ? from : until) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (value != null) {
      setState(() {
        if (start) {
          from = value;
        } else {
          until = value;
        }
        result = '';
      });
    }
  }

  List<Note> _notes(Library lib) => NoteFilter.apply(
    lib.active,
    from: byDates ? from : null,
    until: byDates ? until : null,
  ).where((n) => byDates || selected.contains(n.id)).toList();
  Future<void> _generate(Library lib) async {
    if (from != null && until != null && from!.isAfter(until!)) {
      message(context, 'La fecha inicial debe ser anterior a la fecha final.');
      return;
    }
    final notes = _notes(lib);
    if (notes.isEmpty) {
      message(context, 'Selecciona al menos un apunte con texto.');
      return;
    }
    if (external) {
      setState(() => result = ContextPrompt.build(notes, instruction));
      return;
    }
    if (ref.read(aiPort).configured &&
        !await confirm(
          context,
          'Procesar con IA',
          'Se enviará únicamente el texto seleccionado al servicio de IA. ¿Continuar?',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await runAction(context, () async {
      final text = notes.map((n) => '${n.title}\n${n.plainText}').join('\n\n');
      final value = await ref
          .read(controllerProvider.notifier)
          .transform(text, AiAction.summarize);
      if (mounted) setState(() => result = value);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider).value ?? const Library([], [], []);
    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas de IA')),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 720,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              const Meta('MOTOR CONTEXTUAL'),
              const SizedBox(height: 8),
              Text(
                external ? 'Enviar a una IA externa' : 'Generar resumen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Generar resumen'),
                    selected: !external,
                    onSelected: (_) => setState(() {
                      external = false;
                      result = '';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('IA externa'),
                    selected: external,
                    onSelected: (_) => setState(() {
                      external = true;
                      result = '';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Seleccionar temas'),
                    selected: !byDates,
                    onSelected: (_) => setState(() {
                      byDates = false;
                      result = '';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Seleccionar fechas'),
                    selected: byDates,
                    onSelected: (_) => setState(() {
                      byDates = true;
                      result = '';
                    }),
                  ),
                ],
              ),
              if (byDates) ...[
                const SectionTitle('Ventana temporal'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _date(true),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        'Desde ${from == null ? 'el inicio' : dateLabel(from!)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _date(false),
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(
                        'Hasta ${until == null ? 'hoy' : dateLabel(until!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        from = DateTime.now().subtract(const Duration(days: 6));
                        until = DateTime.now();
                        result = '';
                      }),
                      child: const Text('Últimos 7 días'),
                    ),
                  ],
                ),
                Meta('${_notes(lib).length} apuntes en el rango'),
              ] else ...[
                SectionTitle(
                  'Listado de temas',
                  action: TextButton(
                    onPressed: () => setState(() {
                      if (selected.length == lib.active.length) {
                        selected.clear();
                      } else {
                        selected.addAll(lib.active.map((n) => n.id));
                      }
                      result = '';
                    }),
                    child: const Text('Todos / ninguno'),
                  ),
                ),
                for (final n in lib.active)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(n.title, style: const TextStyle(fontSize: 12)),
                    subtitle: Meta('${n.topic} · ${n.words} palabras'),
                    value: selected.contains(n.id),
                    onChanged: (v) => setState(() {
                      v == true ? selected.add(n.id) : selected.remove(n.id);
                      result = '';
                    }),
                  ),
              ],
              if (external) ...[
                const SectionTitle('Añadir instrucción'),
                for (final s in [
                  'Genera un mapa mental en Markdown y Mermaid.',
                  'Genera una infografía con jerarquía y secciones.',
                  'Genera un gráfico y explica los datos disponibles.',
                  'Genera apuntes ilustrados con descripciones de imágenes.',
                ])
                  ListTile(
                    leading: Icon(
                      instruction == s
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    onTap: () => setState(() {
                      instruction = s;
                      result = '';
                    }),
                    title: Text(s, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              if (!external && !ref.read(aiPort).configured)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Surface(
                    child: Text(
                      'Modo demostrativo: se extraen frases del texto local. No se consulta un modelo de IA.',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : () => _generate(lib),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  busy
                      ? 'Procesando…'
                      : external
                      ? 'Preparar contexto'
                      : 'Generar',
                ),
              ),
              if (result.isNotEmpty) ...[
                SectionTitle(
                  external ? 'Prompt estructurado' : 'Resumen generado',
                ),
                Surface(child: SelectableText(result)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: result));
                        if (context.mounted) {
                          message(context, 'Copiado al portapapeles.');
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar'),
                    ),
                    if (!external && widget.onInsert != null)
                      FilledButton.icon(
                        onPressed: () => runAction(context, () async {
                          await widget.onInsert!(result);
                          if (context.mounted) Navigator.pop(context);
                        }),
                        icon: const Icon(Icons.vertical_align_bottom, size: 18),
                        label: const Text('Insertar en apunte'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
