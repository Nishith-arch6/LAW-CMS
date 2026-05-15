class HearingModel {
  final int id;
  final int caseId;
  final String? caseTitle;
  final String hearingDate;
  final String? hearingTime;
  final String? courtRoom;
  final String? purpose;
  final String? notes;
  final bool reminderSent;
  final String status;
  final String? createdAt;

  HearingModel({
    required this.id,
    required this.caseId,
    this.caseTitle,
    required this.hearingDate,
    this.hearingTime,
    this.courtRoom,
    this.purpose,
    this.notes,
    this.reminderSent = false,
    required this.status,
    this.createdAt,
  });

  factory HearingModel.fromJson(Map<String, dynamic> json) => HearingModel(
    id: json['id'] as int,
    caseId: json['case_id'] as int,
    caseTitle: json['case_title'] as String?,
    hearingDate: json['hearing_date'] as String,
    hearingTime: json['hearing_time'] as String?,
    courtRoom: json['court_room'] as String?,
    purpose: json['purpose'] as String?,
    notes: json['notes'] as String?,
    reminderSent: json['reminder_sent'] as bool? ?? false,
    status: json['status'] as String,
    createdAt: json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'case_id': caseId,
    'hearing_date': hearingDate,
    'hearing_time': hearingTime,
    'court_room': courtRoom,
    'purpose': purpose,
    'notes': notes,
    'reminder_sent': reminderSent,
    'status': status,
  };
}

class HearingCreateRequest {
  final int caseId;
  final String hearingDate;
  final String? hearingTime;
  final String? courtRoom;
  final String? purpose;
  final String? notes;
  final String? status;

  HearingCreateRequest({
    required this.caseId,
    required this.hearingDate,
    this.hearingTime,
    this.courtRoom,
    this.purpose,
    this.notes,
    this.status,
  });

  Map<String, dynamic> toJson() => {
    'case_id': caseId,
    'hearing_date': hearingDate,
    'hearing_time': hearingTime,
    'court_room': courtRoom,
    'purpose': purpose,
    'notes': notes,
    'status': status,
  };
}
