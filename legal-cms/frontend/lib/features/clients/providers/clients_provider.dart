import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/client_model.dart';
import '../../../shared/models/case_model.dart';

class ClientsState {
  final List<ClientModel> clients;
  final ClientModel? clientDetail;
  final List<CaseModel> clientCases;
  final bool isLoading;
  final bool isLoadingDetail;
  final String? error;
  final String search;

  const ClientsState({
    this.clients = const [],
    this.clientDetail,
    this.clientCases = const [],
    this.isLoading = false,
    this.isLoadingDetail = false,
    this.error,
    this.search = '',
  });

  ClientsState copyWith({
    List<ClientModel>? clients,
    ClientModel? clientDetail,
    List<CaseModel>? clientCases,
    bool? isLoading,
    bool? isLoadingDetail,
    String? error,
    String? search,
  }) {
    return ClientsState(
      clients: clients ?? this.clients,
      clientDetail: clientDetail ?? this.clientDetail,
      clientCases: clientCases ?? this.clientCases,
      isLoading: isLoading ?? this.isLoading,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      error: error,
      search: search ?? this.search,
    );
  }
}

class ClientsNotifier extends StateNotifier<ClientsState> {
  final Dio _dio;

  ClientsNotifier(this._dio) : super(const ClientsState());

  Future<void> loadClients({bool refresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'skip': 0, 'limit': 100};
      if (state.search.isNotEmpty) params['search'] = state.search;
      final res = await _dio.get(ApiEndpoints.clients, queryParameters: params);
      final list = (res.data as List)
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(clients: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  Future<void> loadClientDetail(int id) async {
    state = state.copyWith(isLoadingDetail: true, error: null);
    try {
      final res = await _dio.get(ApiEndpoints.clientDetail(id));
      state = state.copyWith(
        clientDetail: ClientModel.fromJson(res.data as Map<String, dynamic>),
        isLoadingDetail: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoadingDetail: false, error: _errorMsg(e));
    }
  }

  Future<void> loadClientCases(int clientId) async {
    try {
      final res = await _dio.get(ApiEndpoints.clientCases(clientId));
      final list = (res.data as List)
          .map((e) => CaseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(clientCases: list);
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMsg(e));
    }
  }

  Future<void> createClient(ClientCreateRequest req) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post(ApiEndpoints.clients, data: req.toJson());
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
      rethrow;
    }
  }

  Future<void> updateClient(int id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.put(ApiEndpoints.clientDetail(id), data: data);
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
      rethrow;
    }
  }

  Future<void> deleteClient(int id) async {
    try {
      await _dio.delete(ApiEndpoints.clientDetail(id));
      state = state.copyWith(
        clients: state.clients.where((c) => c.id != id).toList(),
      );
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMsg(e));
    }
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
    loadClients(refresh: true);
  }

  void clearError() => state = state.copyWith(error: null);
  void clearDetail() => state = state.copyWith(clientDetail: null, clientCases: []);

  String _errorMsg(DioException e) =>
      e.response?.data?['detail'] as String? ?? e.message ?? 'Failed to load clients';
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, ClientsState>((ref) {
  return ClientsNotifier(ref.watch(dioProvider));
});
