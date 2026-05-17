// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../models/document_model.dart';

/// Opens a document viewer modal bottom sheet.
/// For images: shows inline preview with zoom.
/// For PDFs/docs: provides download and open-in-new-tab actions.
void showDocumentViewer(BuildContext context, WidgetRef ref, DocumentModel doc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DocumentViewerBody(doc: doc),
  );
}

class _DocumentViewerBody extends ConsumerStatefulWidget {
  final DocumentModel doc;
  const _DocumentViewerBody({required this.doc});

  @override
  ConsumerState<_DocumentViewerBody> createState() => _DocumentViewerBodyState();
}

class _DocumentViewerBodyState extends ConsumerState<_DocumentViewerBody> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiEndpoints.documentDownload(widget.doc.id),
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted) setState(() { _bytes = res.data as Uint8List; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _isImage => widget.doc.fileType?.startsWith('image/') ?? false;

  void _download() {
    if (_bytes == null) return;
    final blob = html.Blob([_bytes!]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', widget.doc.fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _openInNewTab() {
    if (_bytes == null) return;
    final blob = html.Blob([_bytes!], widget.doc.fileType ?? 'application/octet-stream');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.doc;
    final isImage = _isImage;

    return DraggableScrollableSheet(
      initialChildSize: isImage ? 0.85 : 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _icon(d.fileType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.fileName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(d.formattedSize, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          if (d.description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(d.description!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ),
          if (d.ocrText != null && d.ocrText!.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OCR Text', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.secondary)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(d.ocrText!, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          if (_loading)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SizedBox(height: 200, child: Center(child: Text('Failed to load', style: TextStyle(color: AppColors.error))))
          else if (isImage && _bytes != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.memory(_bytes!, fit: BoxFit.contain),
                ),
              ),
            )
          else if (!isImage)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Preview not available', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download), label: const Text('Download file')),
                  const SizedBox(height: 8),
                  TextButton.icon(onPressed: _openInNewTab, icon: const Icon(Icons.open_in_new), label: const Text('Open in new tab')),
                ],
              ),
            ),
          if (isImage && _bytes != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download), label: const Text('Download')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _icon(String? type) {
    IconData icon;
    if (type == null) icon = Icons.insert_drive_file;
    else if (type.contains('pdf')) icon = Icons.picture_as_pdf;
    else if (type.contains('image')) icon = Icons.image;
    else icon = Icons.insert_drive_file;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppColors.primary, size: 24),
    );
  }
}
