import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/documents_provider.dart';
import '../../../shared/models/document_model.dart';
import '../../../shared/widgets/document_viewer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../core/theme/app_theme.dart';

class DocumentUploadScreen extends ConsumerStatefulWidget {
  final int caseId;

  const DocumentUploadScreen({super.key, required this.caseId});

  @override
  ConsumerState<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(documentsProvider.notifier).loadCaseDocuments(widget.caseId));
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

    final doc = await ref.read(documentsProvider.notifier).uploadDocument(
      caseId: widget.caseId,
      fileBytes: file.bytes!,
      fileName: file.name,
    );
    if (doc != null && mounted) {
      showDocumentViewer(context, ref, doc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Documents')),
      body: LoadingOverlay(
        isLoading: state.isUploading,
        message: 'Uploading... ${(state.uploadProgress * 100).toStringAsFixed(0)}%',
        child: Column(
          children: [
            if (state.isUploading)
              LinearProgressIndicator(value: state.uploadProgress),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.documents.isEmpty
                      ? const EmptyState(
                          icon: Icons.description,
                          title: 'No documents uploaded yet',
                          subtitle: 'Tap the button below to upload files',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.documents.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, i) => _DocumentTile(
                            doc: state.documents[i],
                            onDelete: () {
                              ref.read(documentsProvider.notifier)
                                  .deleteDocument(state.documents[i].id, widget.caseId);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isUploading ? null : _pickAndUpload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  final DocumentModel doc;
  final VoidCallback onDelete;

  const _DocumentTile({required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = doc;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: _fileIcon(d.fileType),
            title: Text(d.fileName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text(d.formattedSize, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  onPressed: () => showDocumentViewer(context, ref, d),
                  tooltip: 'View',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  onPressed: onDelete,
                ),
              ],
            ),
            onTap: () => showDocumentViewer(context, ref, d),
          ),
          if (d.ocrText != null && d.ocrText!.isNotEmpty)
            InkWell(
              onTap: null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.text_snippet, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text('OCR available',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileIcon(String? type) {
    IconData icon;
    if (type == null) icon = Icons.insert_drive_file;
    else if (type.contains('pdf')) icon = Icons.picture_as_pdf;
    else if (type.contains('image')) icon = Icons.image;
    else icon = Icons.insert_drive_file;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}
