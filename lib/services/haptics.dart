// Haptic feedback. Flutter's HapticFeedback does nothing in iOS Safari, so
// the web build uses a browser workaround instead.
export 'haptics_stub.dart' if (dart.library.js_interop) 'haptics_web.dart';
