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
  Future<List<AiQuizQuestion>> generateQuiz(String text) async {
    throw const AppFailure('Conecta la IA para generar un cuestionario.');
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
class RemoteAi implements AiService, AiRunMetadata, AiAccessProvider {
  @override
  String lastModel = '';
  @override
  bool get lastWasDemonstration => false;
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
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
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
              method,
              endpoint.resolve(path),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            });
      if (method != 'GET') request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            Duration(seconds: method == 'GET' ? 5 : 90),
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
          'provider_configuration':
              'El servicio de IA no está configurado correctamente. Inténtalo más tarde.',
          'provider_quota':
              'La cuenta del proveedor no tiene saldo disponible.',
          'pro_unavailable': 'Falta configurar la clave Pro en el servidor.',
          'output_too_long': 'La fuente es demasiado extensa. Divide el documento o analiza menos fuentes juntas.',
          'invalid_input':
              'Revisa el grupo de fuentes y los límites de tamaño.',
          'provider_unavailable': 'El proveedor no pudo leer esta fuente. Revisa el formato o inténtalo después.',
          'auth_required': 'Inicia sesión con Google para usar la IA.',
          'google_account_required':
              'La IA está disponible para cuentas de Google.',
          'server_configuration': 'El servicio de IA aún no está configurado.',
          'quota_unavailable':
              'No se pudo verificar tu límite de uso. Inténtalo de nuevo.',
          'budget_unavailable': 'No se pudo verificar el límite del servicio. Inténtalo más tarde.',

          'content_blocked': 'Esta función no puede crear o mejorar instrucciones para causar daño. Puedes trabajar con apuntes educativos seguros.',
          'daily_limit': 'Alcanzaste el límite diario. Vuelve mañana.',
          'global_limit': 'El servicio de IA alcanzó su límite diario. Vuelve mañana.',
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
      if (value['model'] is String) lastModel = value['model'] as String;
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
  Future<List<AiQuizQuestion>> generateQuiz(String text) async {
    if (text.trim().isEmpty || text.length > 12000) {
      throw const AppFailure(
        'El apunte debe tener texto y no superar 12000 caracteres.',
      );
    }
    final response = await _post('v1/transform', {
      'text': text,
      'action': 'quiz',
    });
    final rawQuestions = response['questions'];
    if (rawQuestions is! List ||
        rawQuestions.length < 3 ||
        rawQuestions.length > 5) {
      throw const AppFailure('La IA devolvió un cuestionario incompleto.');
    }
    final questions = <AiQuizQuestion>[];
    for (final raw in rawQuestions) {
      if (raw is! Map) {
        throw const AppFailure('La IA devolvió una pregunta no válida.');
      }
      final prompt = raw['question'];
      final rawOptions = raw['options'];
      final answerIndex = raw['answerIndex'];
      final explanation = raw['explanation'];
      if (prompt is! String ||
          prompt.trim().isEmpty ||
          rawOptions is! List ||
          rawOptions.length != 4 ||
          answerIndex is! int ||
          answerIndex < 0 ||
          answerIndex >= 4 ||
          (explanation != null && explanation is! String) ||
          rawOptions.any(
            (option) => option is! String || option.trim().isEmpty,
          )) {
        throw const AppFailure('La IA devolvió una pregunta no válida.');
      }
      final options = rawOptions
          .cast<String>()
          .map((option) => option.trim())
          .toList();
      if (options.map((option) => option.toLowerCase()).toSet().length != 4) {
        throw const AppFailure('La IA devolvió opciones repetidas.');
      }
      questions.add(
        AiQuizQuestion(
          prompt: prompt.trim(),
          options: options,
          answerIndex: answerIndex,
          explanation: explanation is String ? explanation.trim() : '',
        ),
      );
    }
    return questions;
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
      'categories': <Map<String, String>>[],
      'notes': library.active
          .take(500)
          .map((n) => {'id': n.id, 'folderId': n.folderId, 'title': n.title})
          .toList(),
    });
    AnalysisProposal decode(
      Map<String, dynamic> value, {
      List<AnalysisProposal> items = const [],
    }) => AnalysisProposal(
      text: value['text'] as String? ?? '',
      summary: value['summary'] as String? ?? '',
      title: value['title'] as String? ?? '',
      topic: value['topic'] as String? ?? '',
      folderName: value['folderName'] as String? ?? '',
      folderId: value['folderId'] as String? ?? '',
      noteId: value['noteId'] as String? ?? '',
      noteTitle: value['noteTitle'] as String? ?? '',
      model: value['model'] as String? ?? lastModel,
      reason: value['reason'] as String? ?? '',
      academic: value['academic'] as bool? ?? true,
      readable: value['readable'] as bool? ?? true,
      partial: value['partial'] as bool? ?? false,
      sourceIndex: value['sourceIndex'] as int? ?? 0,
      items: items,
    );
    final items = (j['items'] as List? ?? [])
        .whereType<Map>()
        .map((v) => decode(Map<String, dynamic>.from(v)))
        .toList();
    if (items.isNotEmpty && items.length != files.length) {
      throw const AppFailure('Faltan resultados de algunas fuentes.');
    }
    return decode(j, items: items);
  }

  @override
  Future<AiAccess> refreshAccess() async {
    final j = await _post('v1/status', const {}, method: 'GET');
    return AiAccess(
      pro: j['pro'] == true,
      vision: j['vision'] == true,
      model: j['model'] as String? ?? '',
      remaining: j['remaining'] as int? ?? 0,
      limit: j['limit'] as int? ?? 0,
      used: j['used'] as int? ?? 0,
      globalRemaining: j['globalRemaining'] as int? ?? -1,
      globalLimit: j['globalLimit'] as int? ?? 0,
    );
  }
}
