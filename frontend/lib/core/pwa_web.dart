import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

final JSObject _global = globalContext;

// Web implementation of PWA install using package:web + dart:js_interop.

/// Attaches listeners for the custom install events dispatched by
/// `web/index.html`. `onAvailable` / `onInstalled` update the app UI state.
void pwaInit(void Function() onAvailable, void Function() onInstalled) {
  web.window.addEventListener(
    'nowcast-install-available',
    ((web.Event e) {
      onAvailable();
    }).toJS,
  );
  web.window.addEventListener(
    'nowcast-installed',
    ((web.Event e) {
      onInstalled();
    }).toJS,
  );
}

/// Calls the `nowcastPromptInstall()` function defined in `web/index.html`.
Future<void> pwaPromptInstall() async {
  final fn = _global.getProperty('nowcastPromptInstall'.toJS);
  if (fn == null) return;
  final prompt = fn as JSFunction;
  prompt.callAsFunction(_global);
}