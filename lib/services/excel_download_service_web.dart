import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web-specific implementation for Excel file downloads
/// This uses the browser's Blob API to trigger downloads
Future<String> downloadForWeb(Uint8List fileBytes, String fileName) async {
  try {
    // Convert Uint8List to JSUint8Array and wrap in JSArray
    final jsUint8Array = fileBytes.toJS;
    final jsArray = [jsUint8Array].toJS;
    
    // Create a Blob from the bytes with proper MIME type for Excel
    final blob = web.Blob(
      jsArray,
      web.BlobPropertyBag(
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    );
    
    // Create object URL from blob
    final objectUrl = web.URL.createObjectURL(blob);
    
    // Create a temporary anchor element to trigger download
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = objectUrl;
    anchor.download = fileName;
    anchor.style.display = 'none';
    
    // Add to document, click, and remove
    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);
    
    // Clean up the object URL after a short delay to ensure download starts
    Future.delayed(const Duration(milliseconds: 100), () {
      web.URL.revokeObjectURL(objectUrl);
    });
    
    // Return success message for web
    return 'Excel file downloaded successfully. Check your browser downloads folder.';
  } catch (e) {
    throw Exception('Web download failed: $e');
  }
}