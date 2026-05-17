import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/document_model.dart';

class DocumentsState {
  final List<DocumentModel> documents;
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress;
  final String? error;

  const DocumentsState({
    this.documents = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.error,
  });

  DocumentsState copyWith({
    List<DocumentModel>? documents,
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? error,
  }) {
    return DocumentsState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
    );
  }
}

class DocumentsNotifier extends StateNotifier<DocumentsState> {
  final Dio _dio;

  DocumentsNotifier(this._dio) : super(const DocumentsState());

  Future<void> loadCaseDocuments(int caseId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get(ApiEndpoints.caseDocuments(caseId));
      final list = (res.data as List)
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(documents: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  Future<DocumentModel?> uploadDocument({
    required int caseId,
    required Uint8List fileBytes,
    required String fileName,
    String? description,
  }) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0, error: null);
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'case_id': caseId,
        'description': description,
      });

      final res = await _dio.post(
        '${ApiEndpoints.documents}/upload',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
          connectTimeout: const Duration(seconds: 60),
        ),
      );

      state = state.copyWith(isUploading: false, uploadProgress: 1);
      await loadCaseDocuments(caseId);
      return DocumentModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      state = state.copyWith(isUploading: false, error: _errorMsg(e));
      return null;
    }
  }

  Future<void> deleteDocument(int docId, int caseId) async {
    try {
      await _dio.delete(ApiEndpoints.documentDownload(docId));
      await loadCaseDocuments(caseId);
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMsg(e));
    }
  }

  String _errorMsg(DioException e) =>
      e.response?.data?['detail'] as String? ?? e.message ?? 'Something went wrong';
}

final documentsProvider = StateNotifierProvider<DocumentsNotifier, DocumentsState>((ref) {
  return DocumentsNotifier(ref.watch(dioProvider));
});
