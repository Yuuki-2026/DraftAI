import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';

/// Direct, guest-owned OpenAI Chat Completions compatible provider.
/// Credentials are supplied by the guest and persisted only in SecureStore.
class GuestOpenAi implements AiService, AiRunMetadata {
  final Uri endpoint;
  final String apiKey;
  final String model;
  final http.Client client;
  Completer<void>? _abort;

  GuestOpenAi({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.client,
  });

  @override
  String lastModel = '';
  @override
  bool get lastWasDemonstration => false;
  @override
  bool get configured => true;

  @override
  void cancel() {
    if (_abort != null && !_abort!.isCompleted) _abort!.complete();
  }

  Future<String> _complete(List<Map<String, Object?>> messages) async {
    if (_abort != null) {
      throw const AppFailure('Espera a que termine la operación actual.');
    }
    final abort = Completer<void>();
    _abort = abort;
    try {
      final request =
          http.AbortableRequest(
              'POST',
              endpoint.resolve('chat/completions'),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            })
            ..body = jsonEncode({
              'model': model,
              'messages': messages,
              'stream': false,
            });
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        switch (response.statusCode) {
          case 401:
          case 403:
            throw const AppFailure(
              'El proveedor rechazó la clave. Revísala en la configuración de IA de Invitado.',
            );
          case 404:
            throw const AppFailure(
              'El proveedor no encontró el modelo o la dirección configurada.',
            );
          case 429:
            throw const AppFailure(
              'El proveedor alcanzó su límite o cuota. Revisa tu cuenta e inténtalo más tarde.',
            );
          default:
            throw const AppFailure(
              'El proveedor no pudo completar la solicitud. Inténtalo de nuevo.',
            );
        }
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      final responseModel = value['model'];
      if (responseModel is String && responseModel.isNotEmpty) {
        lastModel = responseModel;
      } else {
        lastModel = model;
      }
      final choices = value['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const FormatException();
      }
      final message = (choices.first as Map)['message'];
      if (message is! Map) throw const FormatException();
      final content = message['content'];
      if (content is String && content.trim().isNotEmpty) return content.trim();
      if (content is List) {
        final parts = content
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .toList();
        if (parts.isNotEmpty) return parts.join('\n').trim();
      }
      throw const FormatException();
    } on AppFailure {
      rethrow;
    } on http.RequestAbortedException {
      throw const AppFailure('Operación cancelada. Tus archivos se conservan.');
    } on TimeoutException {
      throw const AppFailure(
        'El proveedor tardó demasiado en responder. Inténtalo de nuevo.',
      );
    } catch (_) {
      throw const AppFailure(
        'No se pudo conectar con el proveedor o su respuesta no es válida.',
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
    final instruction = action == AiAction.summarize
        ? 'Resume el apunte en español con ideas principales claras. Conserva datos, fórmulas y términos importantes. No inventes información. Devuelve solo el resumen.'
        : 'Mejora la redacción y el formato del apunte en español sin cambiar su significado. Conserva datos, fórmulas y términos. Devuelve solo el texto editado.';
    return _complete([
      {'role': 'system', 'content': instruction},
      {'role': 'user', 'content': text},
    ]);
  }

  @override
  Future<List<AiQuizQuestion>> generateQuiz(String text) async {
    if (text.trim().isEmpty || text.length > 12000) {
      throw const AppFailure(
        'El apunte debe tener texto y no superar 12000 caracteres.',
      );
    }
    final response = await _complete([
      {
        'role': 'system',
        'content': 'Crea de 3 a 5 preguntas de opción múltiple en español basadas únicamente en el apunte. Responde solo JSON válido, sin Markdown, con esta estructura: {"questions":[{"question":"...","options":["...","...","...","..."],"answerIndex":0,"explanation":"..."}]}. Cada pregunta debe tener cuatro opciones distintas y una respuesta correcta.',
      },
      {'role': 'user', 'content': text},
    ]);
    final value = _decodeJson(response);
    final rawQuestions = value['questions'];
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
          rawOptions.any(
            (option) => option is! String || option.trim().isEmpty,
          )) {
        throw const AppFailure('La IA devolvió una pregunta no válida.');
      }
      final options = rawOptions.cast<String>().map((v) => v.trim()).toList();
      if (options.map((v) => v.toLowerCase()).toSet().length != 4) {
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
    if (files.isEmpty) {
      throw const AppFailure('Selecciona al menos una imagen o documento.');
    }
    if (files.fold<int>(0, (total, file) => total + file.bytes.length) >
        15 * 1024 * 1024) {
      throw const AppFailure(
        'Reduce el tamaño de las fuentes. El proveedor Invitado admite hasta 15 MB por solicitud.',
      );
    }
    if (files.any((file) => file.mime == 'application/pdf')) {
      throw const AppFailure(
        'Este proveedor procesa imágenes y texto, pero no archivos PDF. Extrae o exporta el texto del documento y vuelve a intentarlo.',
      );
    }
    final content = <Map<String, Object?>>[];
    final instructions = StringBuffer(
      'Analiza cada fuente por separado en español. Extrae fielmente el texto visible y genera un título, tema y resumen breve. No inventes contenido ni fuerces una carpeta si no coincide. Devuelve solo JSON válido con la estructura {"items":[{"sourceIndex":0,"text":"...","summary":"...","title":"...","topic":"...","folderName":"","folderId":"","noteId":"","noteTitle":"","reason":"...","academic":true,"readable":true,"partial":false}]}. Incluye exactamente un elemento por fuente y usa los índices indicados. Carpetas existentes: ',
    );
    instructions.write(
      jsonEncode(
        library.folders
            .map((folder) => {'id': folder.id, 'name': folder.name})
            .toList(),
      ),
    );
    instructions.write('. Apuntes existentes (solo para sugerir destinos): ');
    instructions.write(
      jsonEncode(
        library.active
            .take(200)
            .map(
              (note) => {
                'id': note.id,
                'folderId': note.folderId,
                'title': note.title,
              },
            )
            .toList(),
      ),
    );
    content.add({'type': 'text', 'text': instructions.toString()});
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      if (const {
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/gif',
      }.contains(file.mime.toLowerCase())) {
        content.add({'type': 'text', 'text': 'Fuente $i: ${file.name}'});
        content.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:${file.mime};base64,${base64Encode(file.bytes)}',
          },
        });
      } else if (file.mime.startsWith('text/')) {
        content.add({
          'type': 'text',
          'text':
              'Fuente $i (${file.name}):\n${utf8.decode(file.bytes, allowMalformed: true)}',
        });
      } else {
        throw const AppFailure(
          'Este tipo de archivo no es compatible con el proveedor elegido.',
        );
      }
    }
    final response = await _complete([
      {'role': 'user', 'content': content},
    ]);
    final value = _decodeJson(response);
    final rawItems = value['items'];
    if (rawItems is! List || rawItems.length != files.length) {
      throw const AppFailure('Faltan resultados de algunas fuentes.');
    }
    final items = <AnalysisProposal>[];
    for (var i = 0; i < rawItems.length; i++) {
      final raw = rawItems[i];
      if (raw is! Map) {
        throw const AppFailure('El proveedor devolvió un resultado no válido.');
      }
      items.add(
        AnalysisProposal(
          text: raw['text'] as String? ?? '',
          summary: raw['summary'] as String? ?? '',
          title: raw['title'] as String? ?? '',
          topic: raw['topic'] as String? ?? '',
          folderName: raw['folderName'] as String? ?? '',
          folderId: raw['folderId'] as String? ?? '',
          noteId: raw['noteId'] as String? ?? '',
          noteTitle: raw['noteTitle'] as String? ?? '',
          reason: raw['reason'] as String? ?? '',
          academic: raw['academic'] as bool? ?? true,
          readable: raw['readable'] as bool? ?? true,
          partial: raw['partial'] as bool? ?? false,
          sourceIndex: raw['sourceIndex'] as int? ?? i,
          model: lastModel,
        ),
      );
    }
    return AnalysisProposal(
      text: items
          .map((item) => item.text)
          .where((v) => v.isNotEmpty)
          .join('\n\n'),
      summary: items
          .map((item) => item.summary)
          .where((v) => v.isNotEmpty)
          .join('\n\n'),
      title: items.length == 1 ? items.first.title : 'Fuentes analizadas',
      topic: items.length == 1 ? items.first.topic : '',
      folderName: items.length == 1 ? items.first.folderName : '',
      model: lastModel,
      items: items,
    );
  }
}

Map<String, dynamic> _decodeJson(String source) {
  var normalized = source.trim();
  if (normalized.startsWith('```')) {
    normalized = normalized
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
  final value = jsonDecode(normalized);
  if (value is! Map<String, dynamic>) {
    throw const AppFailure(
      'La IA devolvió una respuesta estructurada no válida.',
    );
  }
  return value;
}
