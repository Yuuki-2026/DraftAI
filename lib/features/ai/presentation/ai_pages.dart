import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/ports.dart';
import 'connection_dialog.dart';
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
    final service = ref.read(aiPort);
    final connection = service is AiConnection ? service as AiConnection : null;
    final lib = ref.watch(libraryProvider).value ?? const Library([], [], []);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Herramientas de IA'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 720,
          child: ListView(
            children: [
              if (connection != null)
                ListTile(
                  leading: Icon(
                    service.configured ? Icons.link : Icons.link_off,
                  ),
                  title: Text(
                    tr(
                      context,
                      service.configured
                          ? 'IA conectada'
                          : 'Conectar IA de prueba',
                    ),
                  ),
                  subtitle: Text(
                    service.configured
                        ? connection.model
                        : tr(context, 'Sin conexión a IA'),
                  ),
                  onTap: () async {
                    if (await connectAiDialog(context, connection) && mounted) {
                      setState(() {});
                    }
                  },
                  trailing: service.configured
                      ? IconButton(
                          tooltip: tr(context, 'Desconectar'),
                          onPressed: () async {
                            await connection.disconnect();
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        )
                      : const Icon(Icons.chevron_right),
                ),
              SizedBox(height: 16),
              Meta(tr(context, 'MOTOR CONTEXTUAL')),
              SizedBox(height: 8),
              Text(
                external ? 'Enviar a una IA externa' : 'Generar resumen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(tr(context, 'Generar resumen')),
                    selected: !external,
                    onSelected: (_) => setState(() {
                      external = false;
                      result = '';
                    }),
                  ),
                  ChoiceChip(
                    label: Text(tr(context, 'IA externa')),
                    selected: external,
                    onSelected: (_) => setState(() {
                      external = true;
                      result = '';
                    }),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(tr(context, 'Seleccionar temas')),
                    selected: !byDates,
                    onSelected: (_) => setState(() {
                      byDates = false;
                      result = '';
                    }),
                  ),
                  ChoiceChip(
                    label: Text(tr(context, 'Seleccionar fechas')),
                    selected: byDates,
                    onSelected: (_) => setState(() {
                      byDates = true;
                      result = '';
                    }),
                  ),
                ],
              ),
              if (byDates) ...[
                SectionTitle('Ventana temporal'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _date(true),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        '${tr(context, "Desde")} ${from == null ? tr(context, "el inicio") : dateLabel(from!)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _date(false),
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(
                        '${tr(context, "Hasta")} ${until == null ? tr(context, "hoy") : dateLabel(until!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        from = DateTime.now().subtract(const Duration(days: 6));
                        until = DateTime.now();
                        result = '';
                      }),
                      child: Text(tr(context, 'Últimos 7 días')),
                    ),
                  ],
                ),
                Meta(tr(context, '${_notes(lib).length} apuntes en el rango')),
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
                    child: Text(tr(context, 'Todos / ninguno')),
                  ),
                ),
                for (final n in lib.active)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(n.title, style: const TextStyle(fontSize: 12)),
                    subtitle: Meta(
                      tr(context, '${n.topic} · ${n.words} palabras'),
                    ),
                    value: selected.contains(n.id),
                    onChanged: (v) => setState(() {
                      v == true ? selected.add(n.id) : selected.remove(n.id);
                      result = '';
                    }),
                  ),
              ],
              if (external) ...[
                SectionTitle('Añadir instrucción'),
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
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Surface(
                    child: Text(
                      tr(
                        context,
                        'Modo demostrativo: se extraen frases del texto local. No se consulta un modelo de IA.',
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : () => _generate(lib),
                icon: busy
                    ? SizedBox(
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
                SizedBox(height: 12),
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
                      label: Text(tr(context, 'Copiar')),
                    ),
                    if (!external && widget.onInsert != null)
                      FilledButton.icon(
                        onPressed: () => runAction(context, () async {
                          await widget.onInsert!(result);
                          if (context.mounted) Navigator.pop(context);
                        }),
                        icon: const Icon(Icons.vertical_align_bottom, size: 18),
                        label: Text(tr(context, 'Insertar en apunte')),
                      ),
                  ],
                ),
              ],
              SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
