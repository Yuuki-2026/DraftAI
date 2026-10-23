import 'ai_quota_card.dart';
import '../../notes/domain/note_sections.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/ports.dart';
import 'connection_dialog.dart';
import '../../notes/presentation/rich_ai_text.dart';
import '../../notes/domain/entities.dart';
import '../../notes/domain/use_cases.dart';
import '../../notes/presentation/controller.dart';

class AiPage extends ConsumerStatefulWidget {
  final List<Note> initialNotes;
  final Future<void> Function(String, String)? onInsert;
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
  String resultModel = '';
  bool verified = false, checkingConnection = false;
  final selectedTopics = <String, Set<String>>{};
  @override
  void initState() {
    super.initState();
    selected.addAll(widget.initialNotes.map((n) => n.id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyConnection());
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

  Future<void> _verifyConnection() async {
    final service = ref.read(aiPort);
    final connection = service is AiConnection ? service : null;
    if (connection == null || !service.configured) {
      if (mounted) setState(() => verified = false);
      return;
    }
    if (!connection.isGoogleAccount) {
      if (mounted) setState(() => verified = true);
      return;
    }
    if (service is! AiAccessProvider) {
      if (mounted) setState(() => verified = false);
      return;
    }
    setState(() => checkingConnection = true);
    var ok = false;
    try {
      await (service as AiAccessProvider).refreshAccess();
      ok = true;
    } catch (_) {}
    if (mounted) {
      setState(() {
        verified = ok;
        checkingConnection = false;
      });
    }
  }

  List<Note> _available(Library lib) => {
    for (final n in lib.active) n.id: n,
    for (final n in widget.initialNotes) n.id: n,
  }.values.toList();

  List<Note> _notes(Library lib) =>
      _available(lib)
          .where((n) => selected.contains(n.id))
          .map(
            (n) => NoteSections.select(
              n,
              topics: selectedTopics[n.id],
              from: byDates ? from : null,
              until: byDates ? until : null,
            ),
          )
          .whereType<Note>()
          .toList();

  Future<void> _generate(Library lib) async {
    if (from != null && until != null && from!.isAfter(until!)) {
      message(context, 'La fecha inicial debe ser anterior a la fecha final.');
      return;
    }
    if (!external && !ref.read(aiPort).configured) {
      final service = ref.read(aiPort);
      if (service is! AiConnection ||
          !await connectAiDialog(context, service as AiConnection)) {
        return;
      }
      if (!mounted) return;
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
      if (mounted) {
        setState(() {
          result = value;
          verified = true;
          resultModel = aiModelLabel(ref.read(aiPort));
        });
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(aiPort);
    final connection = service is AiConnection ? service as AiConnection : null;
    final lib = ref.watch(libraryProvider).value ?? const Library([], [], []);
    final available = _available(lib);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Herramientas de IA'))),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 720,
          child: ListView(
            children: [
              const AiQuotaCard(),
              const SizedBox(height: 12),
              if (connection != null)
                ListTile(
                  leading: Icon(verified ? Icons.link : Icons.link_off),
                  title: Text(
                    tr(
                      context,
                      checkingConnection
                          ? 'Comprobando conexión…'
                          : connection.isGoogleAccount
                          ? verified
                                ? 'IA de DraftAI'
                                : 'IA en la nube no disponible'
                          : verified
                          ? 'Proveedor configurado'
                          : 'Conectar IA',
                    ),
                  ),
                  subtitle: Text(
                    connection.isGoogleAccount
                        ? verified
                              ? connection.model
                              : tr(
                                  context,
                                  'La conexión de Azure se habilitará cuando el servicio esté configurado.',
                                )
                        : verified
                        ? tr(
                            context,
                            'Cuota y disponibilidad según tu proveedor.',
                          )
                        : tr(
                            context,
                            'Configura URL, modelo y clave API para este dispositivo.',
                          ),
                  ),
                  onTap: connection.isGoogleAccount
                      ? null
                      : () async {
                          if (await connectAiDialog(context, connection) &&
                              mounted) {
                            await _verifyConnection();
                            ref.invalidate(aiAccessProvider);
                          }
                        },
                  trailing: service.configured && connection.canDisconnect
                      ? IconButton(
                          tooltip: tr(context, 'Desconectar'),
                          onPressed: () async {
                            await connection.disconnect();
                            ref.invalidate(aiAccessProvider);
                            if (mounted) setState(() => verified = false);
                          },
                          icon: const Icon(Icons.close),
                        )
                      : connection.isGoogleAccount && service.configured
                      ? const Icon(Icons.cloud_done_outlined)
                      : connection.isGoogleAccount
                      ? const Icon(Icons.cloud_off_outlined)
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
              ],
              ...[
                SectionTitle(
                  'Apuntes y temas',
                  action: TextButton(
                    onPressed: () => setState(() {
                      if (selected.length == available.length) {
                        selected.clear();
                      } else {
                        selected.addAll(available.map((n) => n.id));
                      }
                      result = '';
                    }),
                    child: Text(tr(context, 'Todos / ninguno')),
                  ),
                ),
                ExpansionTile(
                  title: Text(
                    '${selected.length} ${tr(context, 'seleccionados')} / ${available.length}',
                  ),
                  subtitle: Text(
                    tr(
                      context,
                      'Despliega o contrae la lista para revisar los apuntes',
                    ),
                  ),
                  children: [
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: available.length,
                        itemBuilder: (c, i) {
                          final n = available[i];
                          return Column(
                            children: [
                              CheckboxListTile(
                                title: Text(
                                  n.title,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                subtitle: Meta(n.topic),
                                value: selected.contains(n.id),
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() {
                                        v == true
                                            ? selected.add(n.id)
                                            : selected.remove(n.id);
                                        if (v == true) {
                                          selectedTopics.remove(n.id);
                                        }
                                        result = '';
                                      }),
                              ),
                              if (selected.contains(n.id))
                                for (final part in NoteSections.read(n))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: CheckboxListTile(
                                      dense: true,
                                      title: Text(
                                        part.title,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      subtitle: Text(
                                        NoteSections.label(part.date),
                                      ),
                                      value:
                                          selectedTopics[n.id]?.contains(
                                            part.id,
                                          ) ??
                                          true,
                                      onChanged: busy
                                          ? null
                                          : (v) => setState(() {
                                              final ids = selectedTopics
                                                  .putIfAbsent(
                                                    n.id,
                                                    () =>
                                                        NoteSections.read(n)
                                                            .map((p) => p.id)
                                                            .toSet(),
                                                  );
                                              v == true
                                                  ? ids.add(part.id)
                                                  : ids.remove(part.id);
                                              result = '';
                                            }),
                                    ),
                                  ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
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
                        'Conecta la IA para resumir tus apuntes. No se generará un resultado simulado.',
                      ),
                    ),
                  ),
                ),
              Meta(
                tr(
                  context,
                  'Solo se enviarán los apuntes y temas marcados. Las fechas filtran la última edición de cada tema.',
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
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Meta(
                        external
                            ? tr(
                                context,
                                'Contexto preparado sin consultar un modelo',
                              )
                            : '${tr(context, 'Generado por IA')} · $resultModel',
                      ),
                      const SizedBox(height: 10),
                      RichAiText(result),
                    ],
                  ),
                ),
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
                          await widget.onInsert!(result, resultModel);
                          if (context.mounted) Navigator.pop(context);
                        }),
                        icon: const Icon(Icons.vertical_align_bottom, size: 18),
                        label: Text(tr(context, 'Añadir resumen al final')),
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
