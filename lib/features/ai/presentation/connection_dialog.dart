import 'package:flutter/material.dart';

import '../../../core/presentation/strings.dart';
import '../../notes/domain/ports.dart';

Future<bool> connectAiDialog(
  BuildContext context,
  AiConnection connection,
) async {
  final endpoint = TextEditingController(text: connection.endpoint),
      code = TextEditingController();
  var busy = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(tr(dialog, 'Conectar IA de prueba')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: endpoint,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: tr(context, 'URL HTTPS'),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: code,
                  enabled: !busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: tr(dialog, 'Código de conexión'),
                    helperText: tr(
                      dialog,
                      'Usa el código Pro de prueba para analizar fuentes.',
                    ),
                  ),
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
                        await connection.connect(endpoint.text, code.text);
                        if (dialog.mounted) Navigator.pop(dialog, true);
                      } catch (e) {
                        if (dialog.mounted) {
                          set(() {
                            error = '$e';
                            busy = false;
                          });
                        }
                      }
                    },
              child: Text(tr(dialog, 'Conectar')),
            ),
          ],
        ),
      ),
    ),
  );
  endpoint.dispose();
  code.dispose();
  return result ?? false;
}
