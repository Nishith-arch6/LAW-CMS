import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/documents_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../../shared/models/document_model.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class AllDocumentsState {
  final List<DocumentModel> documents;
  final bool isLoading;
  final String? error;
  final String search;
  final bool hasMore;
  final bool isUploading;
  final double uploadProgress;

  const AllDocumentsState({
    this.documents = const [],
    this.isLoading = false,
    this.error,
    this.search = '',
    this.hasMore = true,
    this.isUploading = false,
    this.uploadProgress = 0,
  });

  AllDocumentsState copyWith({
    List<DocumentModel>? documents,
    bool? isLoading,
    String? error,
    String? search,
    bool? hasMore,
    bool? isUploading,
    double? uploadProgress,
  }) {
    return AllDocumentsState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      search: search ?? this.search,
      hasMore: hasMore ?? this.hasMore,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}

class AllDocumentsNotifier extends StateNotifier<AllDocumentsState> {
  final Dio _dio;

  AllDocumentsNotifier(this._dio) : super(const AllDocumentsState());

  Future<void> loadDocuments({bool refresh = false}) async {
    if (refresh) state = state.copyWith(documents: [], hasMore: true);
    if (!state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final params = <String, dynamic>{
        'skip': state.documents.length,
        'limit': 30,
      };
      if (state.search.isNotEmpty) params['search'] = state.search;

      final res = await _dio.get(ApiEndpoints.documentsList, queryParameters: params);
      final list = (res.data as List)
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        documents: refresh ? list : [...state.documents, ...list],
        isLoading: false,
        hasMore: list.length >= 30,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail'] as String? ?? e.message ?? 'Something went wrong',
      );
    }
  }

  Future<void> uploadDocument({
    required int caseId,
    required String filePath,
    required String fileName,
  }) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0, error: null);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'case_id': caseId,
      });
      await _dio.post(
        '${ApiEndpoints.documentsList}upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(uploadProgress: sent / total);
          }
        },
      );
      state = state.copyWith(isUploading: false, uploadProgress: 1);
      await loadDocuments(refresh: true);
    } on DioException catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.response?.data?['detail'] as String? ?? e.message ?? 'Something went wrong',
      );
    }
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
    loadDocuments(refresh: true);
  }
}

final allDocumentsProvider = StateNotifierProvider<AllDocumentsNotifier, AllDocumentsState>((ref) {
  return AllDocumentsNotifier(ref.watch(dioProvider));
});

class DocumentsListScreen extends ConsumerStatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  ConsumerState<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends ConsumerState<DocumentsListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(allDocumentsProvider.notifier).loadDocuments(refresh: true));
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(allDocumentsProvider.notifier).loadDocuments();
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    _showCasePicker(file.path!, file.name);
  }

  void _showCasePicker(String filePath, String fileName) {
    final casesAsync = ref.read(casesProvider.notifier);
    casesAsync.loadCases(refresh: true);
    showDialog(
      context: context,
      builder: (ctx) => _CasePickerDialog(
        filePath: filePath,
        fileName: fileName,
        onUpload: (caseId) {
          ref.read(allDocumentsProvider.notifier).uploadDocument(
            caseId: caseId,
            filePath: filePath,
            fileName: fileName,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allDocumentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Documents')),
      body: Column(
        children: [
          if (state.isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text('Uploading... ${(state.uploadProgress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(allDocumentsProvider.notifier).setSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: (q) => ref.read(allDocumentsProvider.notifier).setSearch(q),
            ),
          ),
          const SizedBox(height: 8),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(state.error!, style: const TextStyle(color: AppColors.error)),
            ),
          Expanded(
            child: state.isLoading && state.documents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No documents found', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.documents.length + (state.isLoading ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= state.documents.length) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ));
                          }
                          return _DocumentListTile(state.documents[i]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isUploading ? null : _pickAndUpload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
    );
  }
}

class _DocumentListTile extends ConsumerWidget {
  final DocumentModel doc;

  const _DocumentListTile(this.doc);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/cases/${doc.caseId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _fileIcon(doc.fileType),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.fileName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.folder, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doc.caseTitle ?? 'Case #${doc.caseId}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(doc.formattedSize, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                        if (doc.uploadedAt != null) ...[
                          const SizedBox(width: 8),
                          Text(doc.uploadedAt!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chevron_right, color: AppColors.secondary, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileIcon(String? type) {
    if (type == null) return const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 22);
    if (type.contains('pdf')) return const Icon(Icons.picture_as_pdf, color: AppColors.error, size: 22);
    if (type.contains('image')) return const Icon(Icons.image, color: AppColors.secondary, size: 22);
    return const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 22);
  }
}

class _CasePickerDialog extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;
  final void Function(int caseId) onUpload;

  const _CasePickerDialog({
    required this.filePath,
    required this.fileName,
    required this.onUpload,
  });

  @override
  ConsumerState<_CasePickerDialog> createState() => _CasePickerDialogState();
}

class _CasePickerDialogState extends ConsumerState<_CasePickerDialog> {
  int? _selectedCaseId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(casesProvider.notifier).loadCases(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final casesState = ref.watch(casesProvider);
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Select Case'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${widget.fileName}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            casesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : casesState.cases.isEmpty
                    ? const Text('No cases available')
                    : DropdownButtonFormField<int>(
                        value: _selectedCaseId,
                        decoration: const InputDecoration(labelText: 'Case *'),
                        isExpanded: true,
                        hint: const Text('Select a case'),
                        items: casesState.cases.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.caseNumber} — ${c.title}'),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedCaseId = v!),
                      ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedCaseId == null
              ? null
              : () {
                  widget.onUpload(_selectedCaseId!);
                  Navigator.pop(context);
                },
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
