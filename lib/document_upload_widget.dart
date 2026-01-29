import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

class ApplicationDocumentUpload extends StatefulWidget {
  final String applicationId;
  final Function(Map<String, DocumentInfo>) onDocumentsUploaded;

  const ApplicationDocumentUpload({
    super.key,
    required this.applicationId,
    required this.onDocumentsUploaded,
  });

  @override
  State<ApplicationDocumentUpload> createState() =>
      _ApplicationDocumentUploadState();
}

class _ApplicationDocumentUploadState extends State<ApplicationDocumentUpload> {
  final Map<String, DocumentInfo?> _documents = {
    'cv': null,
    'cover_letter': null,
    'id_document': null,
    'academic_certificate': null,
    'professional_certificate': null,
  };

  final Map<String, bool> _uploading = {};
  final Map<String, double> _uploadProgress = {};

  // Document type configurations
  final Map<String, DocumentTypeConfig> _documentConfigs = {
    'cv': DocumentTypeConfig(
      title: 'CV / Resume',
      description: 'Upload your latest CV or Resume',
      icon: Icons.description_rounded,
      color: const Color(0xFF1976D2),
      required: true,
      acceptedFormats: ['pdf', 'doc', 'docx'],
      maxSize: 5 * 1024 * 1024, // 5MB
    ),
    'cover_letter': DocumentTypeConfig(
      title: 'Cover Letter',
      description: 'Optional cover letter',
      icon: Icons.article_rounded,
      color: const Color(0xFF388E3C),
      required: false,
      acceptedFormats: ['pdf', 'doc', 'docx', 'txt'],
      maxSize: 2 * 1024 * 1024, // 2MB
    ),
    'id_document': DocumentTypeConfig(
      title: 'ID Document',
      description: 'National ID or Passport',
      icon: Icons.badge_rounded,
      color: const Color(0xFFF57C00),
      required: true,
      acceptedFormats: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 3 * 1024 * 1024, // 3MB
    ),
    'academic_certificate': DocumentTypeConfig(
      title: 'Academic Certificates',
      description: 'Degree, diploma, or certificates',
      icon: Icons.school_rounded,
      color: const Color(0xFF7B1FA2),
      required: true,
      acceptedFormats: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024, // 5MB
    ),
    'professional_certificate': DocumentTypeConfig(
      title: 'Professional Certificates',
      description: 'Training certificates, licenses',
      icon: Icons.workspace_premium_rounded,
      color: const Color(0xFF00796B),
      required: false,
      acceptedFormats: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024, // 5MB
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  color: Color(0xFF1A237E),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Documents',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please upload all required documents to complete your application',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Document Upload Cards
          ..._documentConfigs.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDocumentUploadCard(
                entry.key,
                entry.value,
              ),
            );
          }),

          const SizedBox(height: 24),

          // Upload Summary
          _buildUploadSummary(),

          const SizedBox(height: 24),

          // Submit Button
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadCard(
      String documentKey, DocumentTypeConfig config) {
    final document = _documents[documentKey];
    final isUploading = _uploading[documentKey] ?? false;
    final progress = _uploadProgress[documentKey] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: config.required && document == null
              ? Colors.orange.withValues(alpha:0.3)
              : Colors.grey.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  config.icon,
                  color: config.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          config.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        if (config.required) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (document != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // File Info or Upload Button
          if (document == null) ...[
            // Upload Zone
            InkWell(
              onTap: isUploading
                  ? null
                  : () => _pickAndUploadDocument(documentKey, config),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: isUploading
                    ? Column(
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              config.color,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Uploading... ${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: config.color,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: config.color,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click to upload or drag and drop',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accepted formats: ${config.acceptedFormats.join(", ").toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            'Max size: ${_formatFileSize(config.maxSize)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ] else ...[
            // Uploaded File Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(document.fileType),
                      color: config.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.fileName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A237E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatFileSize(document.fileSize)} • Uploaded ${_formatDate(document.uploadedDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _previewDocument(document),
                        icon: const Icon(Icons.visibility_rounded),
                        tooltip: 'Preview',
                        color: Colors.blue.shade700,
                      ),
                      IconButton(
                        onPressed: () => _removeDocument(documentKey),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Remove',
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadSummary() {
    final required = _documentConfigs.entries
        .where((e) => e.value.required)
        .length;
    final uploadedRequired = _documentConfigs.entries
        .where((e) => e.value.required && _documents[e.key] != null)
        .length;
    final total = _documents.length;
    final uploaded = _documents.values.where((doc) => doc != null).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: uploadedRequired == required
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: uploadedRequired == required
              ? Colors.green.shade200
              : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            uploadedRequired == required
                ? Icons.check_circle_rounded
                : Icons.warning_rounded,
            color: uploadedRequired == required
                ? Colors.green.shade700
                : Colors.orange.shade700,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uploadedRequired == required
                      ? 'All required documents uploaded!'
                      : 'Upload required documents to continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: uploadedRequired == required
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploaded $uploadedRequired of $required required documents • $uploaded of $total total',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final required = _documentConfigs.entries
        .where((e) => e.value.required)
        .length;
    final uploadedRequired = _documentConfigs.entries
        .where((e) => e.value.required && _documents[e.key] != null)
        .length;
    final canSubmit = uploadedRequired == required;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canSubmit ? _submitDocuments : null,
        icon: const Icon(Icons.send_rounded),
        label: const Text(
          'Submit Application',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadDocument(
      String documentKey, DocumentTypeConfig config) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: config.acceptedFormats,
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileSize = await file.length();

      // Validate file size
      if (fileSize > config.maxSize) {
        _showError(
          'File too large',
          'Maximum file size is ${_formatFileSize(config.maxSize)}',
        );
        return;
      }

      setState(() {
        _uploading[documentKey] = true;
        _uploadProgress[documentKey] = 0.0;
      });

      // Upload to Firebase Storage
      final fileName = path.basename(file.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('applications/${widget.applicationId}/$documentKey/$fileName');

      final uploadTask = storageRef.putFile(file);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress[documentKey] =
              snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Create document info
      final documentInfo = DocumentInfo(
        fileName: fileName,
        fileType: path.extension(fileName).replaceAll('.', ''),
        storageUrl: downloadUrl,
        fileSize: fileSize,
        uploadedDate: DateTime.now(),
        documentType: documentKey,
      );

      setState(() {
        _documents[documentKey] = documentInfo;
        _uploading[documentKey] = false;
      });

      _showSuccess('Document uploaded successfully');
    } catch (e) {
      setState(() {
        _uploading[documentKey] = false;
      });
      _showError('Upload failed', e.toString());
    }
  }

  void _removeDocument(String documentKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Document'),
        content: const Text('Are you sure you want to remove this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _documents[documentKey] = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _previewDocument(DocumentInfo document) {
    // Implement document preview
    // You can use url_launcher or a PDF viewer
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.fileName),
        content: const Text('Preview functionality coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _submitDocuments() {
    final uploadedDocs = Map<String, DocumentInfo>.fromEntries(
      _documents.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(e.key, e.value!)),
    );

    widget.onDocumentsUploaded(uploadedDocs);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

// Supporting Classes
class DocumentInfo {
  final String fileName;
  final String fileType;
  final String storageUrl;
  final int fileSize;
  final DateTime uploadedDate;
  final String documentType;
  final bool isVerified;

  DocumentInfo({
    required this.fileName,
    required this.fileType,
    required this.storageUrl,
    required this.fileSize,
    required this.uploadedDate,
    required this.documentType,
    this.isVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'storageUrl': storageUrl,
      'fileSize': fileSize,
      'uploadedDate': uploadedDate.toIso8601String(),
      'documentType': documentType,
      'isVerified': isVerified,
    };
  }
}

class DocumentTypeConfig {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool required;
  final List<String> acceptedFormats;
  final int maxSize;

  DocumentTypeConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.required,
    required this.acceptedFormats,
    required this.maxSize,
  });
}