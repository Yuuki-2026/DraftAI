import 'dart:convert';

import '../../notes/domain/entities.dart';

abstract final class FileValidation {
  static const maxBytes = 15 * 1024 * 1024;
  static void validate(PickedFile f) {
    final b = f.bytes;
    if (b.isEmpty || b.length > maxBytes) {
      throw const AppFailure('Archivo vacío o mayor de 15 MB.');
    }
    final name = f.name.toLowerCase();
    bool starts(List<int> magic) =>
        b.length >= magic.length &&
        List.generate(magic.length, (i) => b[i] == magic[i]).every((v) => v);
    var valid = false;
    switch (f.mime) {
      case 'application/pdf':
        valid =
            name.endsWith('.pdf') &&
            starts([37, 80, 68, 70, 45]) &&
            latin1
                .decode(b.sublist(b.length > 2048 ? b.length - 2048 : 0))
                .contains('%%EOF');
      case 'image/png':
        valid =
            name.endsWith('.png') &&
            starts([137, 80, 78, 71, 13, 10, 26, 10]) &&
            b.length >= 33;
        if (valid) {
          final d = b.buffer.asByteData(b.offsetInBytes, b.lengthInBytes);
          final w = d.getUint32(16), h = d.getUint32(20);
          valid = w > 0 && h > 0 && w * h <= 24000000;
        }
      case 'image/jpeg':
        valid =
            (name.endsWith('.jpg') || name.endsWith('.jpeg')) &&
            starts([255, 216, 255]) &&
            b.length >= 4;
        if (valid) {
          var found = false, i = 2;
          while (i + 8 < b.length) {
            if (b[i] != 255) {
              i++;
              continue;
            }
            final marker = b[i + 1];
            i += 2;
            if (marker == 0xd9 || marker == 0xda) break;
            if (marker == 0 ||
                marker == 255 ||
                marker == 0xd8 ||
                (marker >= 0xd0 && marker <= 0xd7)) {
              continue;
            }
            final size = (b[i] << 8) + b[i + 1];
            if (size < 2 || i + size > b.length) break;
            if ([0xc0, 0xc1, 0xc2].contains(marker)) {
              final h = (b[i + 3] << 8) + b[i + 4],
                  w = (b[i + 5] << 8) + b[i + 6];
              found = w > 0 && h > 0 && w * h <= 24000000;
              break;
            }
            i += size;
          }
          valid = found;
        }
      case 'image/webp':
        valid =
            name.endsWith('.webp') &&
            b.length >= 30 &&
            latin1.decode(b.sublist(0, 4)) == 'RIFF' &&
            latin1.decode(b.sublist(8, 12)) == 'WEBP';
        if (valid && latin1.decode(b.sublist(12, 16)) == 'VP8X') {
          final w = 1 + b[24] + (b[25] << 8) + (b[26] << 16),
              h = 1 + b[27] + (b[28] << 8) + (b[29] << 16);
          valid = w * h <= 24000000;
        }
      case 'text/plain':
        valid =
            (name.endsWith('.txt') || name.endsWith('.md')) && !b.contains(0);
        if (valid) {
          try {
            utf8.decode(b);
          } catch (_) {
            valid = false;
          }
        }
    }
    if (!valid) {
      throw const AppFailure(
        'El contenido del archivo no coincide con su formato o supera los límites permitidos.',
      );
    }
  }
}
