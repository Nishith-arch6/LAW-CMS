class CaseNoteModel {
  final int id;
  final int caseId;
  final String content;
  final int authorId;
  final String? authorName;
  final String? createdAt;

  CaseNoteModel({
    required this.id,
    required this.caseId,
    required this.content,
    required this.authorId,
    this.authorName,
    this.createdAt,
  });

  factory CaseNoteModel.fromJson(Map<String, dynamic> json) => CaseNoteModel(
    id: json['id'] as int,
    caseId: json['case_id'] as int,
    content: json['content'] as String,
    authorId: json['author_id'] as int,
    authorName: json['author_name'] as String?,
    createdAt: json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'content': content,
  };
}
