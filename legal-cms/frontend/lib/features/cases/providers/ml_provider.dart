import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class MlSuggestion {
  final String category;
  final double confidence;

  MlSuggestion({required this.category, required this.confidence});

  factory MlSuggestion.fromJson(Map<String, dynamic> json) => MlSuggestion(
    category: json['category'] as String? ?? json['suggested_category'] as String? ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  );
}

class MlNotifier extends StateNotifier<AsyncValue<MlSuggestion?>> {
  final Dio _dio;

  MlNotifier(this._dio) : super(const AsyncData(null));

  Future<void> suggestCategory(String title, String description) async {
    state = const AsyncLoading();
    try {
      final res = await _dio.post(ApiEndpoints.mlSuggest, data: {
        'title': title,
        'description': description,
      });
      final suggestion = MlSuggestion.fromJson(res.data as Map<String, dynamic>);
      state = AsyncData(suggestion);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final mlProvider = StateNotifierProvider<MlNotifier, AsyncValue<MlSuggestion?>>((ref) {
  return MlNotifier(ref.watch(dioProvider));
});
