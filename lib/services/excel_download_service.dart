import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_file/open_file.dart';

// Web-specific imports (conditional)
import 'excel_download_service_stub.dart'
    if (dart.library.html) 'excel_download_service_web.dart';

/// Service to handle Excel file downloads across web and mobile platforms
class ExcelDownloadService {
  /// Download Excel file with platform-specific handling
  /// Returns the file path (mobile) or success message (web)
  static Future<String> downloadExcel(
    Uint8List fileBytes,
    String fileName,
  ) async {
    if (kIsWeb) {
      return await downloadForWeb(fileBytes, fileName);
    } else {
      return await _downloadForMobile(fileBytes, fileName);
    }
  }

  /// Download for mobile/desktop platform
  static Future<String> _downloadForMobile(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      // Request storage permissions
      final hasPermission = await _requestStoragePermission();
      
      if (!hasPermission) {
        throw Exception(
          'Storage permission denied. Please enable storage access in Settings.'
        );
      }

      // Get the downloads directory
      final directory = await _getDownloadDirectory();

      // Create the file
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes);

      return file.path;
    } catch (e) {
      throw Exception('Failed to save file on mobile: $e');
    }
  }

  /// Request storage permissions based on Android version
  static Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) {
      // iOS doesn't need permission for app documents
      return true;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    
    if (sdkInt >= 33) {
      // Android 13+: No permission needed for app-specific directories
      return true;
    } else if (sdkInt >= 30) {
      // Android 11-12: Check for storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    } else {
      // Android 10 and below
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
  }

  /// Get the correct download directory based on platform
  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Use app-specific external storage (doesn't require special permissions on Android 11+)
      final directory = await getExternalStorageDirectory();
      
      if (directory != null) {
        // Create AlmaHub/Downloads folder in app-specific directory
        final almaHubDir = Directory('${directory.path}/AlmaHub/Downloads');
        if (!await almaHubDir.exists()) {
          await almaHubDir.create(recursive: true);
        }
        return almaHubDir;
      }
      
      // Fallback to internal storage
      final appDir = await getApplicationDocumentsDirectory();
      final almaHubDir = Directory('${appDir.path}/AlmaHub/Downloads');
      if (!await almaHubDir.exists()) {
        await almaHubDir.create(recursive: true);
      }
      return almaHubDir;
    } else if (Platform.isIOS) {
      // iOS: Use documents directory
      final directory = await getApplicationDocumentsDirectory();
      final almaHubDir = Directory('${directory.path}/AlmaHub/Downloads');
      if (!await almaHubDir.exists()) {
        await almaHubDir.create(recursive: true);
      }
      return almaHubDir;
    } else {
      // Desktop platforms (Windows, macOS, Linux)
      final directory = await getDownloadsDirectory();
      if (directory != null) {
        final almaHubDir = Directory('${directory.path}/AlmaHub');
        if (!await almaHubDir.exists()) {
          await almaHubDir.create(recursive: true);
        }
        return almaHubDir;
      }
      
      // Fallback to documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final almaHubDir = Directory('${appDir.path}/AlmaHub/Downloads');
      if (!await almaHubDir.exists()) {
        await almaHubDir.create(recursive: true);
      }
      return almaHubDir;
    }
  }

  /// Open the downloaded file (mobile only)
  static Future<void> openFile(String filePath) async {
    if (kIsWeb) {
      // Web doesn't need to open - file is auto-downloaded
      return;
    }

    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
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