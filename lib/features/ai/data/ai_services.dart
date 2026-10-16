import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';

class DemonstrationAi implements AiService {
  @override
  void cancel() {}
  @override
  bool get configured => false;
  @override
  Future<String> transform(String text, AiAction action) async {
    if (text.trim().isEmpty) {
      throw const AppFailure('El apunte no contiene texto para procesar.');
    }
    if (action == AiAction.improve) {
      return text
          .trim()
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .where((s) => s.trim().isNotEmpty)
        .take(4);
    return sentences.map((s) => '• ${s.trim()}').join('\n');
  }

  @override
  Future<AnalysisProposal> analyze(
    List<PickedFile> files,
    Library library,
  ) async {
    return AnalysisProposal(
      text: '[Demostración: escribe aquí el texto de tu imagen. No se ha ejecutado OCR.]',
      summary: 'Vista previa del resultado. Configura un proveedor para analizar imágenes reales.',
      title: 'Captura para revisar',
      topic: 'Sin clasificar',
      folderName: library.folders.isEmpty
          ? 'Mis apuntes'
          : library.folders.first.name,
      demonstration: true,
    );
  }
}

/// Stable application contract: providers are replaced on the server, not in UI.
class RemoteAi implements AiService {
  final Uri endpoint;
  final IdentityService identity;
  final http.Client client;
  Completer<void>? _abort;
  @override
  void cancel() {
    if (_abort != null && !_abort!.isCompleted) _abort!.complete();
  }

  RemoteAi(this.endpoint, this.identity, this.client) {
    if (endpoint.scheme != 'https') {
      throw const AppFailure('El servicio de IA debe usar HTTPS.');
    }
  }
  @override
  bool get configured => true;
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await identity.idToken();
    if (token == null) {
      throw const AppFailure(
        'Inicia sesión con Google para usar el servicio de IA.',
      );
    }
    try {
      if (_abort != null) {
        throw const AppFailure('Espera a que termine la operación actual.');
      }
      final abort = Completer<void>();
      _abort = abort;
      final request =
          http.AbortableRequest(
              'POST',
              endpoint.resolve(path),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            })
            ..body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              cancel();
              throw TimeoutException('timeout');
            },
          );
      if (response.statusCode != 200) {
        Map<String, dynamic> error = {};
        try {
          error = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        const allowed = {
          'content_blocked': 'Esta función no puede crear o mejorar instrucciones para causar daño. Puedes trabajar con apuntes educativos seguros.',
          'daily_limit': 'Alcanzaste el límite diario. Vuelve mañana.',
          'global_limit': 'El servidor alcanzó su límite de pruebas por hoy.',
          'pair_required':
              'Vuelve a conectar este dispositivo al servidor de prueba.',
          'pro_required': 'La lectura de imágenes necesita habilitación Pro en el servidor de prueba.',
          'rate_limit': 'Espera un minuto antes de reintentar.',
          'invalid_file': 'El archivo no coincide con el formato permitido.',
        };
        throw AppFailure(
          allowed[error['code']] ??
              'No se pudo procesar el contenido. Tus apuntes se conservan.',
        );
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    } on AppFailure {
      rethrow;
    } on http.RequestAbortedException {
      throw const AppFailure('Operación cancelada. Tus archivos se conservan.');
    } catch (_) {
      throw const AppFailure(
        'No se pudo conectar con la IA o su respuesta no es válida.',
      );
    } finally {
      _abort = null;
    }
  }

  @override
  Future<String> transform(String text, AiAction action) async {
    if (text.trim().isEmpty || text.length > 12000) {
      throw const AppFailure('Selecciona texto de hasta 12000 caracteres.');
    }
    final j = await _post('v1/transform', {
      'text': text,
      'action': action.name,
    });
    final value = j['text'];
    if (value is! String || value.trim().isEmpty) {
      throw const AppFailure('La IA devolvió un texto vacío.');
    }
    return value;
  }

  @override
  Future<AnalysisProposal> analyze(
    List<PickedFile> files,
    Library library,
  ) async {
    final j = await _post('v1/analyze', {
      'files': files
          .map(
            (f) => {
              'name': f.name,
              'mime': f.mime,
              'base64': base64Encode(f.bytes),
            },
          )
          .toList(),
      'folders': library.folders
          .map((f) => {'id': f.id, 'name': f.name})
          .toList(),
      'categories': library.categories
          .map((c) => {'id': c.id, 'folderId': c.folderId, 'name': c.name})
          .toList(),
    });
    if ([
      'text',
      'summary',
      'title',
      'topic',
      'folderName',
    ].any((k) => j[k] is! String)) {
      throw const AppFailure('La propuesta de clasificación está incompleta.');
    }
    return AnalysisProposal(
      text: j['text'] as String,
      summary: j['summary'] as String,
      title: j['title'] as String,
      topic: j['topic'] as String,
      folderName: j['folderName'] as String,
      categoryName: j['categoryName'] as String? ?? '',
    );
  }
}
