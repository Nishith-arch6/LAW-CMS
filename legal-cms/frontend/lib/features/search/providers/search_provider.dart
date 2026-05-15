import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class SearchResult {
  final String type;
  final int id;
  final String title;
  final String? subtitle;
  final String? snippet;

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.snippet,
  });

  factory SearchResult.fromCase(Map<String, dynamic> json) => SearchResult(
    type: 'case',
    id: json['id'] as int,
    title: '${json['case_number']} — ${json['title']}',
    subtitle: json['client_name'] as String?,
    snippet: json['snippet'] as String?,
  );

  factory SearchResult.fromDocument(Map<String, dynamic> json) => SearchResult(
    type: 'document',
    id: json['id'] as int,
    title: json['file_name'] as String,
    subtitle: json['case_title'] as String? ?? 'Case #${json['case_id']}',
    snippet: json['snippet'] as String?,
  );
}

class SearchState {
  final List<SearchResult> caseResults;
  final List<SearchResult> docResults;
  final bool isLoading;
  final String? error;
  final String query;

  const SearchState({
    this.caseResults = const [],
    this.docResults = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    List<SearchResult>? caseResults,
    List<SearchResult>? docResults,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SearchState(
      caseResults: caseResults ?? this.caseResults,
      docResults: docResults ?? this.docResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }

  bool get isEmpty => caseResults.isEmpty && docResults.isEmpty;
}

class SearchNotifier extends StateNotifier<SearchState> {
  final Dio _dio;

  SearchNotifier(this._dio) : super(const SearchState());

  Future<void> search(String q) async {
    if (q.trim().isEmpty) {
      state = const SearchState();
      return;
    }
    state = state.copyWith(isLoading: true, error: null, query: q);
    try {
      final res = await _dio.get(
        ApiEndpoints.search,
        queryParameters: {'q': q, 'type': 'all'},
      );
      final data = res.data as Map<String, dynamic>;

      final cases = (data['cases'] as List?)
              ?.map((e) => SearchResult.fromCase(e as Map<String, dynamic>))
              .toList() ??
          [];
      final docs = (data['documents'] as List?)
              ?.map((e) => SearchResult.fromDocument(e as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(caseResults: cases, docResults: docs, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  void clear() => state = const SearchState();

  String _errorMsg(DioException e) =>
      e.response?.data?['detail'] as String? ?? e.message ?? 'Search failed';
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.watch(dioProvider));
});
