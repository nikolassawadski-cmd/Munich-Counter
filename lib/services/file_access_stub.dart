import 'dart:typed_data';

/// Shares a file via the system share sheet; falls back to a download.
Future<void> shareOrDownload(
    Uint8List bytes, String fileName, String mimeType) async {
  throw UnsupportedError('Nur im Browser verfügbar.');
}

/// Lets the user pick a text file and returns its content (null = cancelled).
Future<String?> pickTextFile({String accept = '.json'}) async {
  throw UnsupportedError('Nur im Browser verfügbar.');
}
