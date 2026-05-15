class DocumentModel {
  final int id;
  final int caseId;
  final String? caseTitle;
  final String fileName;
  final String filePath;
  final String? fileType;
  final int? fileSize;
  final String? description;
  final String? ocrText;
  final int uploadedBy;
  final String? uploadedAt;

  DocumentModel({
    required this.id,
    required this.caseId,
    this.caseTitle,
    required this.fileName,
    required this.filePath,
    this.fileType,
    this.fileSize,
    this.description,
    this.ocrText,
    required this.uploadedBy,
    this.uploadedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
    id: json['id'] as int,
    caseId: json['case_id'] as int,
    caseTitle: json['case_title'] as String?,
    fileName: json['file_name'] as String,
    filePath: json['file_path'] as String,
    fileType: json['file_type'] as String?,
    fileSize: json['file_size'] as int?,
    description: json['description'] as String?,
    ocrText: json['ocr_text'] as String?,
    uploadedBy: json['uploaded_by'] as int,
    uploadedAt: json['uploaded_at'] as String?,
  );

  String get formattedSize {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
