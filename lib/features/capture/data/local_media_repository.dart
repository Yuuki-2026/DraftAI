import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'package:path/path.dart' as p;

import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';
import '../../../core/security/secure_store.dart';

class LocalMediaRepository implements MediaRepository {
  final Directory directory, cache;
  final VaultCipher cipher;
  final String Function() newId;
  LocalMediaRepository(this.directory, this.cache, this.cipher, this.newId);
  static const maxBytes = 15 * 1024 * 1024;
  @override
  Future<List<PickedFile>> pick(CaptureSource source) async {
    try {
      if (source == CaptureSource.files) {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt', 'md'],
        );

        final files = <PickedFile>[];
        for (final f in result.take(20)) {
          if ((await f.length() ?? 0) > maxBytes) {
            throw const AppFailure('Cada archivo debe pesar menos de 15 MB.');
          }
          final bytes = await f.readAsBytes();
          files.add(PickedFile(f.name, _mime(f.name), bytes));
        }
        return files;
      }
      final picker = ImagePicker();
      final images = source == CaptureSource.camera
          ? [
              await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 90,
              ),
            ].whereType<XFile>().toList()
          : await picker.pickMultiImage(imageQuality: 90);
      final files = <PickedFile>[];
      for (final image in images.take(20)) {
        if (await image.length() > maxBytes) {
          throw const AppFailure('Cada imagen debe pesar menos de 15 MB.');
        }
        files.add(
          PickedFile(image.name, _mime(image.name), await image.readAsBytes()),
        );
      }
      return files;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'No se pudo abrir la cámara o los archivos. Revisa los permisos del dispositivo.',
      );
    }
  }

  String _mime(String name) => switch (p.extension(name).toLowerCase()) {
    '.pdf' => 'application/pdf',
    '.txt' || '.md' => 'text/plain',
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  File _file(Attachment a) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(a.id)) {
      throw const AppFailure('Identificador de archivo no válido.');
    }
    return File(p.join(directory.path, '${a.id}.bin'));
  }

  @override
  Future<Attachment> store(PickedFile f) async {
    if (f.bytes.length > maxBytes) {
      throw const AppFailure('El archivo supera 15 MB.');
    }
    await directory.create(recursive: true);
    final a = Attachment(newId(), p.basename(f.name), f.mime);
    await _file(a).writeAsBytes(await cipher.encrypt(f.bytes), flush: true);
    return a;
  }

  @override
  Future<Uint8List> read(Attachment a) async {
    try {
      return Uint8List.fromList(
        await cipher.decrypt(await _file(a).readAsBytes()),
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('No se pudo leer el archivo adjunto.');
    }
  }

  @override
  Future<void> delete(Attachment a) async {
    final f = _file(a);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<int> storageBytes() async {
    var total = 0;
    if (await directory.exists()) {
      await for (final f in directory.list()) {
        if (f is File) total += await f.length();
      }
    }
    return total;
  }

  @override
  Future<int> clearCache() async {
    var total = 0;
    final exports = Directory(p.join(cache.path, 'draftai_exports'));
    if (await exports.exists()) {
      await for (final f in exports.list()) {
        if (f is File) {
          total += await f.length();
          await f.delete();
        }
      }
    }
    return total;
  }
}
