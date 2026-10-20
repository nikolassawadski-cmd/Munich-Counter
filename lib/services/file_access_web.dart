import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens the iOS/Android share sheet (Web Share API with files). Browsers
/// without file sharing (e.g. desktop Firefox) get a regular download.
///
/// Must be called directly from a tap handler: Safari only allows
/// `navigator.share` during a user gesture, so do no slow work before it.
Future<void> shareOrDownload(
    Uint8List bytes, String fileName, String mimeType) async {
  final file = web.File(
    <JSAny>[bytes.toJS].toJS,
    fileName,
    web.FilePropertyBag(type: mimeType),
  );
  final shareData = web.ShareData(files: <web.File>[file].toJS);
  if (web.window.navigator.canShare(shareData)) {
    try {
      await web.window.navigator.share(shareData).toDart;
      return;
    } catch (e) {
      // User closed the share sheet.
      if (e.toString().contains('AbortError')) return;
      // Anything else (e.g. lost user activation): fall back to download.
    }
  }
  _download(file, fileName);
}

void _download(web.Blob blob, String fileName) {
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

/// Lets the user pick a text file and returns its content (null = cancelled).
Future<String?> pickTextFile({String accept = '.json'}) {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.addEventListener(
    'change',
    (web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        completer.complete(null);
        return;
      }
      file.text().toDart.then(
            (text) => completer.complete(text.toDart),
            onError: completer.completeError,
          );
    }.toJS,
  );
  input.addEventListener(
    'cancel',
    (web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS,
  );
  input.click();
  return completer.future;
}
