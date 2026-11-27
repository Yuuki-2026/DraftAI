import 'package:flutter/material.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/ports.dart';

Future<bool> connectAiDialog(
  BuildContext context,
  AiConnection connection,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConnectionDialog(connection),
    ) ??
    false;

class _ConnectionDialog extends StatefulWidget {
  final AiConnection connection;
  const _ConnectionDialog(this.connection);

  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  AiConnection get connection => widget.connection;

  late final String? owner;
  late final AiProvider savedProvider;
  late AiProvider provider;
  late final TextEditingController endpoint;
  late final TextEditingController model;
  final apiKey = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    owner = connection.profileId;
    savedProvider = connection.provider;
    provider = connection.configured ? savedProvider : AiProvider.openAi;
    endpoint = TextEditingController(text: connection.endpoint);
    model = TextEditingController(text: connection.model);
  }

  @override
  void dispose() {
    endpoint.dispose();
    model.dispose();
    apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext dialog) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(tr(dialog, 'Conectar IA')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AiProvider>(
              initialValue: provider,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr(dialog, 'Proveedor de IA'),
              ),
              items: [
                for (final item in AiProvider.values)
                  DropdownMenuItem(
                    value: item,
                    child: Text(switch (item) {
                      AiProvider.openAi => 'OpenAI',
                      AiProvider.claude => 'Claude',
                      AiProvider.gemini => 'Gemini',
                      AiProvider.custom => tr(dialog, 'Servidor personalizado'),
                    }),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null || value == provider) return;
                      apiKey.clear();
                      setState(() {
                        provider = value;
                        error = null;
                      });
                    },
            ),
            if (provider == AiProvider.custom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: endpoint,
                enabled: !busy,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: tr(dialog, 'URL base HTTPS'),
                  hintText: 'https://api.example.com/v1/',
                  helperText: tr(dialog, 'Compatible con Chat Completions.'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model,
                enabled: !busy,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: tr(dialog, 'Modelo'),
                  hintText: tr(dialog, 'nombre-del-modelo'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: apiKey,
              enabled: !busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(
                labelText: tr(dialog, 'Clave API del proveedor'),
                helperText: connection.configured && provider == savedProvider
                    ? tr(
                        dialog,
                        'Si mantienes el servidor, puedes dejar la clave vacía.',
                      )
                    : null,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                dialog,
                'El proveedor recibe el contenido que selecciones y aplica sus tarifas y límites.',
              ),
              style: Theme.of(dialog).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                dialog,
                'La prueba envía un mensaje breve y puede consumir cuota.',
              ),
              style: Theme.of(dialog).textTheme.bodySmall,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(dialog).colorScheme.error),
                  ),
                ),
              ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(dialog, false),
          child: Text(tr(dialog, 'Cancelar')),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (owner == null || owner != connection.profileId) {
                    Navigator.pop(dialog, false);
                    return;
                  }
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await connection.connect(
                      provider,
                      endpoint.text,
                      apiKey.text,
                      model.text,
                    );
                    if (dialog.mounted) Navigator.pop(dialog, true);
                  } catch (e) {
                    if (dialog.mounted) {
                      setState(() {
                        error = localizedFailure(dialog, e);
                        busy = false;
                      });
                    }
                  }
                },
          child: Text(tr(dialog, 'Probar y guardar')),
        ),
      ],
    ),
  );
}
