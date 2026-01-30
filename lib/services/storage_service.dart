import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Sanitizes employee name for use in file paths
  /// Replaces spaces with underscores
  String _sanitizeEmployeeName(String name) {
    if (name.isEmpty) {
      return 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }
    return name.trim().replaceAll(' ', '_').toLowerCase();
  }

  /// Uploads an employee document to Firebase Storage
  /// 
  /// Structure: employee_documents/{employee_name}/{field_name}/{timestamp}_{filename}
  /// 
  /// Parameters:
  /// - employeeName: Full name of the employee (spaces will be replaced with underscores)
  /// - fieldName: Name of the field/document type (e.g., 'id_document', 'kra_pin_certificate')
  /// - file: The file to upload
  /// 
  /// Returns: Download URL of the uploaded file
  Future<String> uploadEmployeeDocument({
    required String employeeName,
    required String fieldName,
    required PlatformFile file,
  }) async {
    _logger.i('=== FILE UPLOAD INITIATED ===');
    _logger.d('Employee Name: $employeeName');
    _logger.d('Field Name: $fieldName');
    _logger.d('File Name: ${file.name}');
    _logger.d('File Size: ${(file.size / 1024).toStringAsFixed(2)} KB');

    try {
      // Sanitize employee name (replace spaces with underscores)
      final sanitizedName = _sanitizeEmployeeName(employeeName);
      _logger.d('Sanitized employee name: $sanitizedName');

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.extension ?? 'pdf';
      final fileName = '${timestamp}_${file.name}';
      
      // Build storage path
      final path = 'employee_documents/$sanitizedName/$fieldName/$fileName';
      _logger.i('Upload path: $path');

      // Get file bytes
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('File bytes are null');
      }

      _logger.d('File bytes loaded: ${bytes.length} bytes');

      // Create reference and upload
      final ref = _storage.ref().child(path);
      
      _logger.d('Starting upload...');
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'employeeName': employeeName,
            'fieldName': fieldName,
            'originalFileName': file.name,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        _logger.d('Upload progress: ${progress.toStringAsFixed(2)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      _logger.i('Upload completed!');

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      _logger.i('✅ File uploaded successfully!');
      _logger.d('Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      _logger.e('❌ UPLOAD ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Deletes an employee document from Firebase Storage
  /// 
  /// Parameters:
  /// - url: The download URL of the file to delete
  Future<void> deleteEmployeeDocument(String url) async {
    _logger.i('=== FILE DELETE INITIATED ===');
    _logger.d('URL: $url');

    try {
      // Get reference from URL
      final ref = _storage.refFromURL(url);
      _logger.d('File path: ${ref.fullPath}');

      // Delete the file
      await ref.delete();
      
      _logger.i('✅ File deleted successfully!');
    } catch (e, stackTrace) {
      _logger.e('❌ DELETE ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Deletes all documents for a specific employee
  /// 
  /// Parameters:
  /// - employeeName: Full name of the employee
  Future<void> deleteAllEmployeeDocuments(String employeeName) async {
    _logger.i('=== DELETING ALL EMPLOYEE DOCUMENTS ===');
    _logger.d('Employee Name: $employeeName');

    try {
      final sanitizedName = _sanitizeEmployeeName(employeeName);
      final path = 'employee_documents/$sanitizedName';
      
      _logger.d('Deleting folder: $path');

      final ref = _storage.ref().child(path);
      final listResult = await ref.listAll();

      _logger.i('Found ${listResult.items.length} files to delete');

      // Delete all files
      for (var item in listResult.items) {
        _logger.d('Deleting: ${item.name}');
        await item.delete();
      }

      // Recursively delete subfolders
      for (var prefix in listResult.prefixes) {
        final subFiles = await prefix.listAll();
        for (var item in subFiles.items) {
          _logger.d('Deleting: ${item.fullPath}');
          await item.delete();
        }
      }

      _logger.i('✅ All employee documents deleted successfully!');
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR DELETING EMPLOYEE DOCUMENTS', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Gets the appropriate content type for a file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  /// Lists all documents for a specific employee
  /// 
  /// Returns: Map of field names to lists of download URLs
  Future<Map<String, List<String>>> listEmployeeDocuments(String employeeName) async {
    _logger.i('=== LISTING EMPLOYEE DOCUMENTS ===');
    _logger.d('Employee Name: $employeeName');

    try {
      final sanitizedName = _sanitizeEmployeeName(employeeName);
      final path = 'employee_documents/$sanitizedName';
      
      final ref = _storage.ref().child(path);
      final listResult = await ref.listAll();

      final Map<String, List<String>> documents = {};

      // List all subfolders (field names)
      for (var prefix in listResult.prefixes) {
        final fieldName = prefix.name;
        final fieldFiles = await prefix.listAll();
        
        final urls = <String>[];
        for (var item in fieldFiles.items) {
          final url = await item.getDownloadURL();
          urls.add(url);
        }
        
        documents[fieldName] = urls;
        _logger.d('Field: $fieldName - ${urls.length} file(s)');
      }

      _logger.i('✅ Found documents for ${documents.length} field(s)');
      return documents;
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR LISTING DOCUMENTS', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Gets metadata for a specific file
  Future<FullMetadata> getFileMetadata(String url) async {
    _logger.i('=== GETTING FILE METADATA ===');
    _logger.d('URL: $url');

    try {
      final ref = _storage.refFromURL(url);
      final metadata = await ref.getMetadata();
      
      _logger.i('✅ Metadata retrieved');
      _logger.d('Content Type: ${metadata.contentType}');
      _logger.d('Size: ${metadata.size} bytes');
      _logger.d('Created: ${metadata.timeCreated}');
      
      return metadata;
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR GETTING METADATA', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}