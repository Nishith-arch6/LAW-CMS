import 'case_model.dart';

class DashboardStats {
  final int totalCases;
  final int activeCases;
  final int pendingHearingsToday;
  final int pendingHearingsWeek;
  final Map<String, int> caseTypeBreakdown;
  final List<CaseSummaryModel> recentCases;

  DashboardStats({
    this.totalCases = 0,
    this.activeCases = 0,
    this.pendingHearingsToday = 0,
    this.pendingHearingsWeek = 0,
    this.caseTypeBreakdown = const {},
    this.recentCases = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    totalCases: json['total_cases'] as int? ?? 0,
    activeCases: json['active_cases'] as int? ?? 0,
    pendingHearingsToday: json['pending_hearings_today'] as int? ?? 0,
    pendingHearingsWeek: json['pending_hearings_week'] as int? ?? 0,
    caseTypeBreakdown: (json['case_type_breakdown'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as int)) ??
        {},
    recentCases: (json['recent_cases'] as List?)
            ?.map((e) => CaseSummaryModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
