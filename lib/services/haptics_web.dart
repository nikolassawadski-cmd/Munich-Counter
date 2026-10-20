import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// A short confirmation tick, e.g. after saving.
///
/// Android browsers support `navigator.vibrate`. iOS Safari does not, but
/// since iOS 18 toggling an `<input type="checkbox" switch>` gives a system
/// haptic, so a hidden one is toggled instead. Must run inside a tap handler.
void hapticTick() {
  try {
    final navigator = web.window.navigator;
    if ((navigator as JSObject).has('vibrate')) {
      navigator.vibrate(15.toJS);
      return;
    }
    final input = web.HTMLInputElement()
      ..type = 'checkbox'
      ..setAttribute('switch', '');
    final label = web.HTMLLabelElement()
      ..style.display = 'none'
      ..append(input);
    web.document.body!.append(label);
    label.click();
    label.remove();
  } catch (_) {
    // Haptics are a nicety; never let them break saving.
  }
}
