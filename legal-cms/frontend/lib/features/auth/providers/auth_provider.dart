import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/auth_models.dart';

enum AuthStatus { unauthenticated, loading, authenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;

  AuthNotifier(this._dio) : super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: LoginRequest(email: email, password: password).toJson(),
      );
      final authRes = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      await saveToken(authRes.accessToken);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: authRes.user,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = 'Login failed';
      if (data is Map) {
        msg = (data['detail'] as String?) ?? msg;
      } else if (data is String) {
        msg = data;
      }
      state = AuthState(status: AuthStatus.error, error: msg);
    }
  }

  Future<void> register(RegisterRequest req) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: req.toJson(),
      );
      final authRes = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      await saveToken(authRes.accessToken);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: authRes.user,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = 'Registration failed';
      if (data is Map) {
        msg = (data['detail'] as String?) ?? msg;
      } else if (data is String) {
        msg = data;
      }
      state = AuthState(status: AuthStatus.error, error: msg);
    }
  }

  Future<void> loadUser() async {
    final token = await getToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _dio.get(ApiEndpoints.me);
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      await deleteToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await deleteToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(dioProvider));
});
