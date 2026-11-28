import 'entities.dart';

abstract final class FolderNames {
  static const maxLength = 80;
  static const duplicateMessage = 'Ya existe una carpeta con ese nombre.';

  static final _whitespace = RegExp(r'\s+');

  static String key(String name) =>
      name.trim().replaceAll(_whitespace, ' ').toLowerCase();

  static bool conflicts(
    String name,
    Iterable<Folder> folders, {
    Folder? current,
  }) {
    final candidate = key(name);
    // A folder already present in an old library can still be recolored.
    if (current != null && key(current.name) == candidate) return false;
    return folders.any(
      (folder) => folder.id != current?.id && key(folder.name) == candidate,
    );
  }

  static String available(String name, Iterable<String> existingNames) {
    final used = existingNames.map(key).toSet();
    if (!used.contains(key(name))) return name;

    for (var number = 2; ; number++) {
      final suffix = ' ($number)';
      final limit = maxLength - suffix.length;
      var length = 0;
      for (final rune in name.runes) {
        final runeLength = rune > 0xffff ? 2 : 1;
        if (length + runeLength > limit) break;
        length += runeLength;
      }
      final candidate = '${name.substring(0, length).trimRight()}$suffix';
      if (!used.contains(key(candidate))) return candidate;
    }
  }
}
