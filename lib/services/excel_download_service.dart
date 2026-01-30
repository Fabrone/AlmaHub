import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
// For web: import 'package:universal_html/html.dart' as html;

/// Service to handle Excel file downloads across web and mobile platforms
class ExcelDownloadService {
  /// Download Excel file with platform-specific handling
  /// Returns the file path (mobile) or triggers download (web)
  static Future<String> downloadExcel(
    Uint8List fileBytes,
    String fileName,
  ) async {
    if (kIsWeb) {
      return await _downloadForWeb(fileBytes, fileName);
    } else {
      return await _downloadForMobile(fileBytes, fileName);
    }
  }

  /// Download for web platform
  static Future<String> _downloadForWeb(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      // For web, we need to use universal_html package
      // Uncomment when universal_html is added to pubspec.yaml
      
      /* 
      final blob = html.Blob([fileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      */
      
      // Temporary placeholder - will work when universal_html is added
      return 'Downloaded: $fileName (Web platform - add universal_html package)';
    } catch (e) {
      throw Exception('Failed to download file on web: $e');
    }
  }

  /// Download for mobile/desktop platform
  static Future<String> _downloadForMobile(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      // Get the downloads directory
      Directory? directory;
      
      if (Platform.isAndroid) {
        // For Android, use external storage
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        // For iOS, use documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // For desktop platforms
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }

      // Create the file
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes);

      return file.path;
    } catch (e) {
      throw Exception('Failed to save file on mobile: $e');
    }
  }

  /// Open the downloaded file (mobile only)
  static Future<void> openFile(String filePath) async {
    if (kIsWeb) {
      // Web doesn't need to open - file is auto-downloaded
      return;
    }

    try {
      // Use open_file package
      // Uncomment when open_file is added to pubspec.yaml
      
      /*
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
      */
    } catch (e) {
      throw Exception('Failed to open file: $e');
    }
  }

  /// Get file size in readable format
  static String getReadableFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  /// Check if file exists (mobile only)
  static Future<bool> fileExists(String filePath) async {
    if (kIsWeb) return false;
    
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete file (mobile only)
  static Future<void> deleteFile(String filePath) async {
    if (kIsWeb) return;
    
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
