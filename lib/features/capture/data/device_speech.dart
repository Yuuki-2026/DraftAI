import 'package:speech_to_text/speech_to_text.dart';

import '../../notes/domain/ports.dart';

class DeviceSpeech implements SpeechService {
  final SpeechToText _speech = SpeechToText();
  @override
  Future<bool> listen(void Function(String) result) async {
    if (!await _speech.initialize()) return false;
    final locales = await _speech.locales();
    final spanish = locales
        .where((l) => l.localeId.startsWith('es'))
        .firstOrNull;
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: spanish?.localeId),
      onResult: (r) => result(r.recognizedWords),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}
