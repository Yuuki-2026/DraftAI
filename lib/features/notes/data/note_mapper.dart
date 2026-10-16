import 'dart:convert';

import '../domain/entities.dart';

class NoteMapper {
  static String encode(Note n) => jsonEncode({
    'v': 2,
    'documentVersion': n.documentVersion,
    'id': n.id,
    'folderId': n.folderId,
    'categoryId': n.categoryId,
    'title': n.title,
    'topic': n.topic,
    'text': n.plainText,
    'document': n.document,
    'summary': n.summary,
    'summaryModel': n.summaryModel,
    'lastAiModel': n.lastAiModel,
    'lastAiAt': n.lastAiAt?.toIso8601String(),
    'created': n.createdAt.toIso8601String(),
    'updated': n.updatedAt.toIso8601String(),
    'deleted': n.deletedAt?.toIso8601String(),
    'attachments': n.attachments.map((a) => a.toJson()).toList(),
  });
  static Note decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['v'] != 1 && j['v'] != 2) {
      throw const AppFailure('Formato de apunte no compatible.');
    }
    return Note(
      id: j['id'] as String,
      folderId: j['folderId'] as String,
      categoryId: j['categoryId'] as String?,
      title: j['title'] as String,
      topic: j['topic'] as String,
      plainText: j['text'] as String,
      document: j['document'] as String,
      documentVersion: j['documentVersion'] as int? ?? 1,
      summary: j['summary'] as String,
      summaryModel: j['summaryModel'] as String? ?? '',
      lastAiModel: j['lastAiModel'] as String? ?? '',
      lastAiAt: DateTime.tryParse(j['lastAiAt'] as String? ?? ''),
      createdAt: DateTime.parse(j['created'] as String),
      updatedAt: DateTime.parse(j['updated'] as String),
      deletedAt: j['deleted'] == null
          ? null
          : DateTime.parse(j['deleted'] as String),
      attachments: (j['attachments'] as List)
          .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}
