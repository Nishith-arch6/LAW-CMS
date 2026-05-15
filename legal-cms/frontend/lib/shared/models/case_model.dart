class CaseModel {
  final int id;
  final String caseNumber;
  final String title;
  final String? description;
  final String caseType;
  final String status;
  final String? courtName;
  final String? courtBuilding;
  final String? courtFloor;
  final String? judgeName;
  final int clientId;
  final String? clientName;
  final String? opposingParty;
  final String? defendingParty;
  final String? filingDate;
  final int advocateId;
  final String? nextHearingDate;
  final bool isDeleted;
  final String? createdAt;
  final String? updatedAt;

  CaseModel({
    required this.id,
    required this.caseNumber,
    required this.title,
    this.description,
    required this.caseType,
    required this.status,
    this.courtName,
    this.courtBuilding,
    this.courtFloor,
    this.judgeName,
    required this.clientId,
    this.clientName,
    this.opposingParty,
    this.defendingParty,
    this.filingDate,
    required this.advocateId,
    this.nextHearingDate,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) => CaseModel(
    id: json['id'] as int,
    caseNumber: json['case_number'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    caseType: json['case_type'] as String,
    status: json['status'] as String,
    courtName: json['court_name'] as String?,
    courtBuilding: json['court_building'] as String?,
    courtFloor: json['court_floor'] as String?,
    judgeName: json['judge_name'] as String?,
    clientId: json['client_id'] as int,
    clientName: json['client_name'] as String?,
    opposingParty: json['opposing_party'] as String?,
    defendingParty: json['defending_party'] as String?,
    filingDate: json['filing_date'] as String?,
    advocateId: json['advocate_id'] as int,
    nextHearingDate: json['next_hearing_date'] as String?,
    isDeleted: json['is_deleted'] as bool? ?? false,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'case_number': caseNumber,
    'title': title,
    'description': description,
    'case_type': caseType,
    'status': status,
    'court_name': courtName,
    'court_building': courtBuilding,
    'court_floor': courtFloor,
    'judge_name': judgeName,
    'client_id': clientId,
    'opposing_party': opposingParty,
    'defending_party': defendingParty,
    'filing_date': filingDate,
  };

  String get statusDisplay {
    switch (status.toUpperCase()) {
      case 'ACTIVE': return 'Active';
      case 'PENDING': return 'Pending';
      case 'CLOSED': return 'Closed';
      case 'ADJOURNED': return 'Adjourned';
      default: return status;
    }
  }
}

class CaseSummaryModel {
  final int id;
  final String caseNumber;
  final String title;
  final String status;
  final String? nextHearingDate;
  final String? clientName;

  CaseSummaryModel({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.status,
    this.nextHearingDate,
    this.clientName,
  });

  factory CaseSummaryModel.fromJson(Map<String, dynamic> json) =>
      CaseSummaryModel(
        id: json['id'] as int,
        caseNumber: json['case_number'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        nextHearingDate: json['next_hearing_date'] as String?,
        clientName: json['client_name'] as String?,
      );
}

class CaseCreateRequest {
  final String caseNumber;
  final String title;
  final String? description;
  final String? caseType;
  final String? status;
  final String? courtName;
  final String? courtBuilding;
  final String? courtFloor;
  final String? judgeName;
  final int clientId;
  final String? opposingParty;
  final String? defendingParty;
  final String? filingDate;

  CaseCreateRequest({
    required this.caseNumber,
    required this.title,
    this.description,
    this.caseType,
    this.status,
    this.courtName,
    this.courtBuilding,
    this.courtFloor,
    this.judgeName,
    required this.clientId,
    this.opposingParty,
    this.defendingParty,
    this.filingDate,
  });

  Map<String, dynamic> toJson() => {
    'case_number': caseNumber,
    'title': title,
    'description': description,
    'case_type': caseType,
    'status': status,
    'court_name': courtName,
    'court_building': courtBuilding,
    'court_floor': courtFloor,
    'judge_name': judgeName,
    'client_id': clientId,
    'opposing_party': opposingParty,
    'defending_party': defendingParty,
    'filing_date': filingDate,
  };
}
