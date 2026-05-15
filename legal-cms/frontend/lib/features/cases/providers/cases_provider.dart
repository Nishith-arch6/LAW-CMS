import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/models/hearing_model.dart';
import '../../../shared/models/document_model.dart';
import '../../../shared/models/case_note_model.dart';
import '../../../shared/models/dashboard_models.dart';

class CasesState {
  final List<CaseModel> cases;
  final CaseModel? caseDetail;
  final DashboardStats? dashboardStats;
  final bool isLoading;
  final bool isLoadingDetail;
  final String? error;
  final int totalCount;
  final int skip;
  final String search;
  final String statusFilter;
  final String caseTypeFilter;
  final List<HearingModel> caseHearings;
  final List<DocumentModel> caseDocuments;
  final List<CaseNoteModel> caseNotes;

  const CasesState({
    this.cases = const [],
    this.caseDetail,
    this.dashboardStats,
    this.isLoading = false,
    this.isLoadingDetail = false,
    this.error,
    this.totalCount = 0,
    this.skip = 0,
    this.search = '',
    this.statusFilter = '',
    this.caseTypeFilter = '',
    this.caseHearings = const [],
    this.caseDocuments = const [],
    this.caseNotes = const [],
  });

  CasesState copyWith({
    List<CaseModel>? cases,
    CaseModel? caseDetail,
    DashboardStats? dashboardStats,
    bool? isLoading,
    bool? isLoadingDetail,
    String? error,
    int? totalCount,
    int? skip,
    String? search,
    String? statusFilter,
    String? caseTypeFilter,
    List<HearingModel>? caseHearings,
    List<DocumentModel>? caseDocuments,
    List<CaseNoteModel>? caseNotes,
  }) {
    return CasesState(
      cases: cases ?? this.cases,
      caseDetail: caseDetail ?? this.caseDetail,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      isLoading: isLoading ?? this.isLoading,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      error: error,
      totalCount: totalCount ?? this.totalCount,
      skip: skip ?? this.skip,
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      caseTypeFilter: caseTypeFilter ?? this.caseTypeFilter,
      caseHearings: caseHearings ?? this.caseHearings,
      caseDocuments: caseDocuments ?? this.caseDocuments,
      caseNotes: caseNotes ?? this.caseNotes,
    );
  }
}

class CasesNotifier extends StateNotifier<CasesState> {
  final Dio _dio;

  CasesNotifier(this._dio) : super(const CasesState());

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get(ApiEndpoints.caseDashboard);
      state = state.copyWith(
        dashboardStats: DashboardStats.fromJson(res.data as Map<String, dynamic>),
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  Future<void> loadCases({bool refresh = false}) async {
    if (refresh) state = state.copyWith(skip: 0, cases: []);
    state = state.copyWith(isLoading: true, error: null);

    try {
      final params = <String, dynamic>{
        'skip': state.skip,
        'limit': 20,
      };
      if (state.search.isNotEmpty) params['search'] = state.search;
      if (state.statusFilter.isNotEmpty) params['status'] = state.statusFilter;
      if (state.caseTypeFilter.isNotEmpty) params['case_type'] = state.caseTypeFilter;

      final res = await _dio.get(ApiEndpoints.cases, queryParameters: params);
      final list = (res.data as List)
          .map((e) => CaseModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        cases: refresh ? list : [...state.cases, ...list],
        totalCount: list.length,
        skip: state.skip + list.length,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  Future<void> loadCaseDetail(int id) async {
    state = state.copyWith(isLoadingDetail: true, error: null);
    try {
      final res = await _dio.get(ApiEndpoints.caseDetail(id));
      final data = res.data as Map<String, dynamic>;

      final hearings = (data['hearings'] as List?)
              ?.map((e) => HearingModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final documents = (data['documents'] as List?)
              ?.map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final notes = (data['notes'] as List?)
              ?.map((e) => CaseNoteModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(
        caseDetail: CaseModel.fromJson(data),
        caseHearings: hearings,
        caseDocuments: documents,
        caseNotes: notes,
        isLoadingDetail: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoadingDetail: false, error: _errorMsg(e));
    }
  }

  Future<void> createCase(CaseCreateRequest req) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post(ApiEndpoints.cases, data: req.toJson());
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
      rethrow;
    }
  }

  Future<void> updateCase(int id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.put(ApiEndpoints.caseDetail(id), data: data);
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
      rethrow;
    }
  }

  Future<void> deleteCase(int id) async {
    try {
      await _dio.delete(ApiEndpoints.caseDetail(id));
      state = state.copyWith(
        cases: state.cases.where((c) => c.id != id).toList(),
      );
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMsg(e));
    }
  }

  void setSearch(String q) {
    state = state.copyWith(search: q, skip: 0);
    loadCases(refresh: true);
  }

  void setStatusFilter(String s) {
    state = state.copyWith(statusFilter: s, skip: 0);
    loadCases(refresh: true);
  }

  void setCaseTypeFilter(String t) {
    state = state.copyWith(caseTypeFilter: t, skip: 0);
    loadCases(refresh: true);
  }

  void clearError() => state = state.copyWith(error: null);
  void clearDetail() => state = state.copyWith(
    caseDetail: null,
    caseHearings: [],
    caseDocuments: [],
    caseNotes: [],
  );

  String _errorMsg(DioException e) =>
      e.response?.data?['detail'] as String? ?? e.message ?? 'Something went wrong';
}

final casesProvider = StateNotifierProvider<CasesNotifier, CasesState>((ref) {
  return CasesNotifier(ref.watch(dioProvider));
});
