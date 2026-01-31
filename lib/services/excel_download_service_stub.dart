import 'dart:typed_data';

/// Stub implementation - should never be called on non-web platforms
Future<String> downloadForWeb(Uint8List fileBytes, String fileName) async {
  throw UnsupportedError('Web download is not supported on this platform');
}
