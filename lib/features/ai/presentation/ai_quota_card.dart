import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design.dart';
import '../../../core/presentation/strings.dart';
import '../../notes/domain/ports.dart';
import '../../notes/presentation/controller.dart';

class AiQuotaCard extends ConsumerWidget {
  const AiQuotaCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(aiPort);
    final AiConnection? connection = service is AiConnection
        ? service as AiConnection
        : null;
    if (connection != null && !connection.isGoogleAccount) {
      return Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'IA de Invitado')),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                connection.configured
                    ? 'Proveedor configurado. La cuota y disponibilidad dependen de ese proveedor.'
                    : 'Conecta un proveedor compatible desde Herramientas de IA.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final quota = ref.watch(aiAccessProvider);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tr(context, 'Usos de IA'))),
              IconButton(
                tooltip: tr(context, 'Actualizar'),
                onPressed: () => ref.invalidate(aiAccessProvider),
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          quota.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Text(
              tr(
                context,
                'No se pudo consultar la cuota. Actualiza para reintentar.',
              ),
            ),
            data: (access) {
              if (access == null) {
                return Text(
                  tr(
                    context,
                    connection?.isGoogleAccount == true
                        ? 'La conexión de IA en la nube aún no está configurada.'
                        : 'Inicia sesión con Google para consultar tu cuota de IA.',
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    access.limit > 0
                        ? tr(
                            context,
                            '${access.used} de ${access.limit} usos · ${access.remaining} disponibles',
                          )
                        : tr(context, '${access.remaining} usos disponibles'),
                  ),
                  if (access.limit > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (access.used / access.limit).clamp(0.0, 1.0),
                    ),
                  ],
                  if (access.globalRemaining >= 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        context,
                        'Servidor: ${access.globalRemaining} de ${access.globalLimit} llamadas disponibles',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'El límite se reinicia a medianoche, hora de Lima. Cada operación correcta cuenta como un uso.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
