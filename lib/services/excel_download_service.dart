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
      
      // Create the full file path
      final filePath = '${directory.path}/$fileName';

      // Create the file and write bytes
      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);
      
      // Verify file was created and has content
      if (!await file.exists()) {
        throw Exception('File was not created at $filePath');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File was created but is empty');
      }
      
      print('✅ Excel file saved successfully to: $filePath');
      print('📊 File size: ${getReadableFileSize(fileSize)}');

      return filePath;
    } catch (e) {
      print('❌ Error saving Excel file: $e');
      throw Exception('Failed to save file on mobile: $e');
    }
  }

  /// Request storage permissions based on Android version
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) {
      // iOS doesn't need permission for app documents directory
      return true;
    }
    
    if (!Platform.isAndroid) {
      // Desktop platforms don't need special permissions
      return true;
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      print('📱 Android SDK version: $sdkInt');
      
      if (sdkInt >= 33) {
        // Android 13+ (API 33+): Use MANAGE_EXTERNAL_STORAGE or scoped storage
        // For app-specific directories, no permission needed
        // For public Downloads folder, we need special permission
        
        // First try to use storage permission
        var status = await Permission.storage.status;
        print('Storage permission status (Android 13+): $status');
        
        if (!status.isGranted) {
          status = await Permission.storage.request();
          print('Storage permission after request: $status');
        }
        
        // If storage permission is not granted, try manageExternalStorage
        if (!status.isGranted) {
          var manageStatus = await Permission.manageExternalStorage.status;
          print('Manage external storage status: $manageStatus');
          
          if (!manageStatus.isGranted) {
            manageStatus = await Permission.manageExternalStorage.request();
            print('Manage external storage after request: $manageStatus');
            return manageStatus.isGranted;
          }
          return manageStatus.isGranted;
        }
        
        return status.isGranted;
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32): Use scoped storage
        var status = await Permission.storage.status;
        print('Storage permission status (Android 11-12): $status');
        
        if (!status.isGranted) {
          status = await Permission.storage.request();
          print('Storage permission after request: $status');
        }
        
        // Also try manageExternalStorage for better access
        if (!status.isGranted) {
          var manageStatus = await Permission.manageExternalStorage.status;
          if (!manageStatus.isGranted) {
            manageStatus = await Permission.manageExternalStorage.request();
          }
          return manageStatus.isGranted;
        }
        
        return status.isGranted;
      } else {
        // Android 10 and below (API 29 and lower)
        var status = await Permission.storage.status;
        print('Storage permission status (Android 10-): $status');
        
        if (!status.isGranted) {
          status = await Permission.storage.request();
          print('Storage permission after request: $status');
        }
        return status.isGranted;
      }
    } catch (e) {
      print('❌ Error requesting storage permission: $e');
      return false;
    }
  }

  /// Get the correct download directory based on platform
  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      try {
        // Try to get the public Downloads directory first
        // This is the standard location users expect
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        // For Android 10+ (API 29+), try to access Downloads folder
        if (sdkInt >= 29) {
          // Try external storage directory first
          final Directory? externalDir = await getExternalStorageDirectory();
          
          if (externalDir != null) {
            // Navigate to the public Downloads folder
            // External storage path is usually: /storage/emulated/0/Android/data/com.yourapp/files
            // We want: /storage/emulated/0/Download
            final pathComponents = externalDir.path.split('/');
            final downloadsPath = '/${pathComponents[1]}/${pathComponents[2]}/Download';
            
            final publicDownloads = Directory(downloadsPath);
            
            // Check if public Downloads exists and is accessible
            if (await publicDownloads.exists()) {
              print('✅ Using public Downloads directory: ${publicDownloads.path}');
              return publicDownloads;
            } else {
              print('⚠️ Public Downloads not accessible, using app-specific folder');
            }
          }
        }
        
        // Fallback: Use app-specific external storage
        final externalDir = await getExternalStorageDirectory();
        
        if (externalDir != null) {
          // Create AlmaHub/Downloads folder in app-specific directory
          final almaHubDir = Directory('${externalDir.path}/AlmaHub/Downloads');
          
          if (!await almaHubDir.exists()) {
            await almaHubDir.create(recursive: true);
            print('📁 Created directory: ${almaHubDir.path}');
          }
          
          print('✅ Using app-specific directory: ${almaHubDir.path}');
          return almaHubDir;
        }
        
        // Last resort: Internal storage
        final appDir = await getApplicationDocumentsDirectory();
        final almaHubDir = Directory('${appDir.path}/AlmaHub/Downloads');
        
        if (!await almaHubDir.exists()) {
          await almaHubDir.create(recursive: true);
          print('📁 Created directory: ${almaHubDir.path}');
        }
        
        print('✅ Using internal directory: ${almaHubDir.path}');
        return almaHubDir;
        
      } catch (e) {
        print('❌ Error getting Android downloads directory: $e');
        // Absolute fallback
        final appDir = await getApplicationDocumentsDirectory();
        return appDir;
      }
    } else if (Platform.isIOS) {
      // iOS: Use documents directory
      final directory = await getApplicationDocumentsDirectory();
      final almaHubDir = Directory('${directory.path}/AlmaHub/Downloads');
      
      if (!await almaHubDir.exists()) {
        await almaHubDir.create(recursive: true);
        print('📁 Created iOS directory: ${almaHubDir.path}');
      }
      
      print('✅ Using iOS directory: ${almaHubDir.path}');
      return almaHubDir;
    } else {
      // Desktop platforms (Windows, macOS, Linux)
      try {
        final directory = await getDownloadsDirectory();
        
        if (directory != null) {
          final almaHubDir = Directory('${directory.path}/AlmaHub');
          
          if (!await almaHubDir.exists()) {
            await almaHubDir.create(recursive: true);
            print('📁 Created desktop directory: ${almaHubDir.path}');
          }
          
          print('✅ Using desktop Downloads directory: ${almaHubDir.path}');
          return almaHubDir;
        }
      } catch (e) {
        print('⚠️ Could not access Downloads directory: $e');
      }
      
      // Fallback to documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final almaHubDir = Directory('${appDir.path}/AlmaHub/Downloads');
      
      if (!await almaHubDir.exists()) {
        await almaHubDir.create(recursive: true);
        print('📁 Created fallback directory: ${almaHubDir.path}');
      }
      
      print('✅ Using fallback directory: ${almaHubDir.path}');
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
      print('📂 Attempting to open file: $filePath');
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist at $filePath');
      }
      
      final result = await OpenFile.open(filePath);
      print('📱 Open file result: ${result.type} - ${result.message}');
      
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('❌ Error opening file: $e');
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
        print('🗑️ File deleted: $filePath');
      }
    } catch (e) {
      print('❌ Error deleting file: $e');
      throw Exception('Failed to delete file: $e');
    }
  }
}