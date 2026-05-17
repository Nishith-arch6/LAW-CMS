import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'api_endpoints.dart';

const _tokenKey = 'jwt_token';

final secureStorage = FlutterSecureStorage();

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: Duration(milliseconds: AppConstants.connectionTimeout),
    receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeout),
    sendTimeout: Duration(milliseconds: 60000),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await secureStorage.read(key: _tokenKey);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        await secureStorage.delete(key: _tokenKey);
      }
      handler.next(error);
    },
  ));

  return dio;
});

Future<void> saveToken(String token) async {
  await secureStorage.write(key: _tokenKey, value: token);
}

Future<void> deleteToken() async {
  await secureStorage.delete(key: _tokenKey);
}

Future<String?> getToken() async {
  return await secureStorage.read(key: _tokenKey);
}
