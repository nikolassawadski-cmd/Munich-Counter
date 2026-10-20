// Browser file APIs. The stub keeps `flutter test` (Dart VM) compiling.
export 'file_access_stub.dart'
    if (dart.library.js_interop) 'file_access_web.dart';
