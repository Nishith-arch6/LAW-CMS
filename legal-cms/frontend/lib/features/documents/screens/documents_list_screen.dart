import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/documents_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../../shared/models/document_model.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/widgets/document_viewer.dart';
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
        '${ApiEndpoints.documentsList}upload',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
          connectTimeout: const Duration(seconds: 60),
        ),
      );
      state = state.copyWith(isUploading: false, uploadProgress: 1);
      await loadDocuments(refresh: true);
      return DocumentModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?
          ?? e.message
          ?? 'Upload failed. Check your connection and try again.';
      state = state.copyWith(
        isUploading: false,
        error: msg,
      );
      return null;
    }
  }

  Future<void> deleteDocument(int docId) async {
    try {
      await _dio.delete(ApiEndpoints.documentDelete(docId));
      await loadDocuments(refresh: true);
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data?['detail'] as String? ?? e.message ?? 'Something went wrong',
      );
    }
  }

  Future<void> deleteDocuments(List<int> docIds) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      for (final id in docIds) {
        await _dio.delete(ApiEndpoints.documentDelete(id));
      }
      await loadDocuments(refresh: true);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
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
  bool _isSelectMode = false;
  final Set<int> _selectedIds = {};

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

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<DocumentModel> docs) {
    setState(() {
      if (_selectedIds.length == docs.length) {
        _selectedIds.clear();
        _isSelectMode = false;
      } else {
        _selectedIds.addAll(docs.map((d) => d.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Documents'),
        content: Text('Remove $count selected document${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = List<int>.from(_selectedIds);
    setState(() {
      _isSelectMode = false;
      _selectedIds.clear();
    });
    ref.read(allDocumentsProvider.notifier).deleteDocuments(ids);
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    _showCasePicker(file.bytes!, file.name);
  }

  Future<void> _showCasePicker(Uint8List fileBytes, String fileName) async {
    final casesAsync = ref.read(casesProvider.notifier);
    casesAsync.loadCases(refresh: true);
    final doc = await showDialog<DocumentModel>(
      context: context,
      builder: (ctx) => _CasePickerDialog(
        fileBytes: fileBytes,
        fileName: fileName,
      ),
    );
    if (doc != null && context.mounted) {
      showDocumentViewer(context, ref, doc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allDocumentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(_isSelectMode ? '${_selectedIds.length} selected' : 'Documents'),
        actions: [
          if (state.documents.isNotEmpty)
            IconButton(
              icon: Icon(_isSelectMode ? Icons.close : Icons.checklist),
              onPressed: _toggleSelectMode,
              tooltip: _isSelectMode ? 'Cancel' : 'Select',
            ),
          if (_isSelectMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () => _selectAll(state.documents),
              tooltip: 'Select all',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isSelectMode && _selectedIds.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withAlpha(20),
              child: TextButton.icon(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                label: Text('Delete ${_selectedIds.length} selected',
                    style: const TextStyle(color: AppColors.error)),
              ),
            ),
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
                          return _DocumentListTile(
                            state.documents[i],
                            isSelectMode: _isSelectMode,
                            isSelected: _selectedIds.contains(state.documents[i].id),
                            onToggle: () => _toggleSelection(state.documents[i].id),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _isSelectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: state.isUploading ? null : _pickAndUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            ),
    );
  }
}

class _DocumentListTile extends ConsumerStatefulWidget {
  final DocumentModel doc;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onToggle;

  const _DocumentListTile(
    this.doc, {
    this.isSelectMode = false,
    this.isSelected = false,
    required this.onToggle,
  });

  @override
  ConsumerState<_DocumentListTile> createState() => _DocumentListTileState();
}

class _DocumentListTileState extends ConsumerState<_DocumentListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.doc;
    return MouseRegion(
      cursor: widget.isSelectMode ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: widget.isSelected ? AppColors.primary.withAlpha(12) : null,
          elevation: _hovered && !widget.isSelectMode ? 3 : 1,
          child: InkWell(
            onTap: widget.isSelectMode ? widget.onToggle : () => context.push('/cases/${d.caseId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isSelectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: widget.isSelected,
                          onChanged: (_) => widget.onToggle(),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _fileIcon(d.fileType),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.fileName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.folder, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                d.caseTitle ?? 'Case #${d.caseId}',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(d.formattedSize, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                            if (d.uploadedAt != null) ...[
                              const SizedBox(width: 8),
                              Text(d.uploadedAt!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                            ],
                          ],
                        ),
                        if (d.description != null) ...[
                          const SizedBox(height: 4),
                          Text(d.description!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    onPressed: () => showDocumentViewer(context, ref, d),
                    tooltip: 'View',
                  ),
                ],
              ),
            ),
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
  final Uint8List fileBytes;
  final String fileName;

  const _CasePickerDialog({
    required this.fileBytes,
    required this.fileName,
  });

  @override
  ConsumerState<_CasePickerDialog> createState() => _CasePickerDialogState();
}

class _CasePickerDialogState extends ConsumerState<_CasePickerDialog> {
  int? _selectedCaseId;
  final _descCtrl = TextEditingController();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(casesProvider.notifier).loadCases(refresh: true));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _doUpload() async {
    if (_selectedCaseId == null) return;
    setState(() => _uploading = true);
    final doc = await ref.read(allDocumentsProvider.notifier).uploadDocument(
      caseId: _selectedCaseId!,
      fileBytes: widget.fileBytes,
      fileName: widget.fileName,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context, doc);
  }

  @override
  Widget build(BuildContext context) {
    final casesState = ref.watch(casesProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return AlertDialog(
      title: Text(_uploading ? 'Uploading...' : 'Upload Document'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: isMobile ? null : 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: ${widget.fileName}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: isMobile ? 2 : 3,
                enabled: !_uploading,
              ),
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
                          onChanged: _uploading ? null : (v) => setState(() => _selectedCaseId = v!),
                        ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_selectedCaseId == null || _uploading)
              ? null
              : _doUpload,
          child: _uploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Upload'),
        ),
      ],
    );
  }
}
