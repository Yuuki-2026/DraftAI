import 'dart:convert';

import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';

class SourceDraft {
  final PickedFile file;
  final AnalysisProposal? proposal;
  String? folderId, noteId;
  String folderName, noteTitle, text, summary;
  bool include, saved = false;
  SourceDraft(this.file, this.proposal, Library lib)
    : folderId = lib.folders.any((f) => f.id == proposal?.folderId)
          ? proposal!.folderId
          : lib.folders
                .where(
                  (f) =>
                      f.name.toLowerCase() ==
                      proposal?.folderName.toLowerCase(),
                )
                .firstOrNull
                ?.id,
      noteId = lib.active.any((n) => n.id == proposal?.noteId)
          ? proposal!.noteId
          : null,
      folderName = proposal?.folderName ?? 'Mis apuntes',
      noteTitle = proposal?.noteTitle.isNotEmpty == true
          ? proposal!.noteTitle
          : proposal?.title ?? 'Nuevo apunte',
      text = proposal?.text ?? '',
      summary = proposal?.summary ?? '',
      include = proposal == null || proposal.academic && proposal.readable;
  factory SourceDraft.manual(PickedFile file, Library lib) {
    final draft = SourceDraft(file, null, lib);
    draft.folderId = lib.folders.firstOrNull?.id;
    draft.folderName = lib.folders.firstOrNull?.name ?? 'Mis apuntes';
    if (file.mime.startsWith('text/')) draft.text = utf8.decode(file.bytes);
    return draft;
  }
  SourceDraft.clone(SourceDraft other)
    : file = other.file,
      proposal = other.proposal,
      folderId = other.folderId,
      noteId = other.noteId,
      folderName = other.folderName,
      noteTitle = other.noteTitle,
      text = other.text,
      summary = other.summary,
      include = other.include {
    saved = other.saved;
  }
  void apply(SourceDraft other) {
    folderId = other.folderId;
    noteId = other.noteId;
    folderName = other.folderName;
    noteTitle = other.noteTitle;
    text = other.text;
    summary = other.summary;
    include = other.include;
  }

  String get model => proposal?.model ?? '';
}
