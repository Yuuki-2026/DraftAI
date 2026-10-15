import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';

class DemonstrationAi implements AiService {
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
      final response = await client
          .post(
            endpoint.resolve(path),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode == 429) {
        throw const AppFailure(
          'El servicio alcanzó su límite. Inténtalo más tarde.',
        );
      }
      if (response.statusCode != 200) {
        throw const AppFailure(
          'El servicio no pudo procesar el contenido. Tus apuntes se conservan.',
        );
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'No se pudo conectar con la IA o su respuesta no es válida.',
      );
    }
  }

  @override
  Future<String> transform(String text, AiAction action) async {
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
