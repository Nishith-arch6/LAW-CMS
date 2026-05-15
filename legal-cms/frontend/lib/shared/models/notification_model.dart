class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final int? caseId;
  final int? hearingId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.caseId,
    this.hearingId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as int,
        type: json['type'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        isRead: json['is_read'] as bool,
        caseId: json['case_id'] as int?,
        hearingId: json['hearing_id'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'message': message,
    'is_read': isRead,
    'case_id': caseId,
    'hearing_id': hearingId,
    'created_at': createdAt.toIso8601String(),
  };
}
