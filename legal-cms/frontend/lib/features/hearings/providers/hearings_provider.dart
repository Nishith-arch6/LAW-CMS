import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/hearing_model.dart';

class HearingsState {
  final List<HearingModel> hearings;
  final List<HearingModel> todayHearings;
  final bool isLoading;
  final String? error;

  const HearingsState({
    this.hearings = const [],
    this.todayHearings = const [],
    this.isLoading = false,
    this.error,
  });

  HearingsState copyWith({
    List<HearingModel>? hearings,
    List<HearingModel>? todayHearings,
    bool? isLoading,
    String? error,
  }) {
    return HearingsState(
      hearings: hearings ?? this.hearings,
      todayHearings: todayHearings ?? this.todayHearings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HearingsNotifier extends StateNotifier<HearingsState> {
  final Dio _dio;

  HearingsNotifier(this._dio) : super(const HearingsState());

  Future<void> loadTodayHearings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get(ApiEndpoints.hearingsToday);
      final list = (res.data as List)
          .map((e) => HearingModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(todayHearings: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  Future<void> loadHearings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get(ApiEndpoints.hearings);
      final list = (res.data as List)
          .map((e) => HearingModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(hearings: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  Future<void> createHearing(HearingCreateRequest req) async {
    try {
      await _dio.post(ApiEndpoints.hearings, data: req.toJson());
      await loadHearings();
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMsg(e));
      rethrow;
    }
  }

  String _errorMsg(DioException e) =>
      e.response?.data?['detail'] as String? ?? e.message ?? 'Something went wrong';
}

final hearingsProvider = StateNotifierProvider<HearingsNotifier, HearingsState>((ref) {
  return HearingsNotifier(ref.watch(dioProvider));
});
