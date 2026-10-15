import 'dart:typed_data';

class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override
  String toString() => message;
}

class Folder {
  final String id, name;
  final int color;
  const Folder(this.id, this.name, this.color);
}

class Category {
  final String id, folderId, name;
  const Category(this.id, this.folderId, this.name);
}

class Attachment {
  final String id, name, mime;
  const Attachment(this.id, this.name, this.mime);
  Map<String, Object> toJson() => {'id': id, 'name': name, 'mime': mime};
  factory Attachment.fromJson(Map<String, dynamic> j) =>
      Attachment(j['id'] as String, j['name'] as String, j['mime'] as String);
}

class Note {
  final String id, folderId, title, topic, plainText, document, summary;
  final String? categoryId;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;
  final List<Attachment> attachments;
  const Note({
    required this.id,
    required this.folderId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.topic = '',
    this.plainText = '',
    this.document = '',
    this.summary = '',
    this.categoryId,
    this.deletedAt,
    this.attachments = const [],
  });

  Note copyWith({
    String? folderId,
    String? title,
    String? topic,
    String? plainText,
    String? document,
    String? summary,
    String? categoryId,
    bool clearCategory = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool restore = false,
    List<Attachment>? attachments,
  }) => Note(
    id: id,
    folderId: folderId ?? this.folderId,
    title: title ?? this.title,
    topic: topic ?? this.topic,
    plainText: plainText ?? this.plainText,
    document: document ?? this.document,
    summary: summary ?? this.summary,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: restore ? null : deletedAt ?? this.deletedAt,
    attachments: List.unmodifiable(attachments ?? this.attachments),
  );

  int get words => plainText.trim().isEmpty
      ? 0
      : plainText.trim().split(RegExp(r'\s+')).length;
}

class Revision {
  final int id;
  final Note note;
  final String reason;
  const Revision(this.id, this.note, this.reason);
}

class Library {
  final List<Folder> folders;
  final List<Category> categories;
  final List<Note> notes;
  const Library(this.folders, this.categories, this.notes);
  List<Note> get active => notes.where((n) => n.deletedAt == null).toList();
  List<Note> get trash => notes.where((n) => n.deletedAt != null).toList();
}

class PickedFile {
  final String name, mime;
  final Uint8List bytes;
  const PickedFile(this.name, this.mime, this.bytes);
}

enum ExportFormat { pdf, word, text, markdown }

enum AiAction { summarize, improve }

enum CaptureSource { camera, gallery, files }
