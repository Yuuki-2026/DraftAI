import 'package:flutter/material.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/ports.dart';

Future<bool> connectAiDialog(
  BuildContext context,
  AiConnection connection,
) async {
  if (connection.isGoogleAccount) {
    message(
      context,
      tr(
        context,
        'La IA de tu cuenta de Google se habilitará al conectar el servicio de DraftAI.',
      ),
    );
    return false;
  }

  final endpoint = TextEditingController(text: connection.endpoint),
      model = TextEditingController(text: connection.model),
      apiKey = TextEditingController();
  var busy = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(tr(dialog, 'Conectar IA')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    dialog,
                    'Usa un proveedor compatible con OpenAI Chat Completions. La disponibilidad y los límites dependen del proveedor que elijas.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: endpoint,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: tr(dialog, 'URL base HTTPS'),
                    hintText: 'https://api.example.com/v1/',
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
                const SizedBox(height: 12),
                TextField(
                  controller: apiKey,
                  enabled: !busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: tr(dialog, 'Clave API del proveedor'),
                    helperText: tr(
                      dialog,
                      connection.configured
                          ? 'Déjala vacía para conservar la clave guardada en este teléfono.'
                          : 'La clave se guarda de forma segura en este teléfono.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    dialog,
                    'El texto o las imágenes que proceses se enviarán al proveedor configurado.',
                  ),
                  style: Theme.of(dialog).textTheme.bodySmall,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(dialog).colorScheme.error,
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
                      set(() => busy = true);
                      try {
                        await connection.connect(
                          endpoint.text,
                          apiKey.text,
                          model.text,
                        );
                        if (dialog.mounted) Navigator.pop(dialog, true);
                      } catch (e) {
                        if (dialog.mounted) {
                          set(() {
                            error = localizedFailure(context, e);
                            busy = false;
                          });
                        }
                      }
                    },
              child: Text(tr(dialog, 'Guardar conexión')),
            ),
          ],
        ),
      ),
    ),
  );
  endpoint.dispose();
  model.dispose();
  apiKey.dispose();
  return result ?? false;
}
