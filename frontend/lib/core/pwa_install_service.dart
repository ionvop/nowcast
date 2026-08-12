import 'package:flutter/foundation.dart';

import 'pwa_stub.dart'
    if (dart.library.js_interop) 'pwa_web.dart' as pwa;

/// PWA install support. Web listens for the `beforeinstallprompt` event
/// (surfaced by `web/index.html` as a `nowcast-install-available` custom
/// event) and exposes a way to trigger the install prompt. On native this is
/// a no-op.
class PwaInstallService extends ChangeNotifier {
  PwaInstallService();

  bool _installAvailable = false;
  bool get installAvailable => _installAvailable;

  /// Wires up web event listeners. Call once at app start.
  void init() {
    if (kIsWeb) {
      pwa.pwaInit(() => _setAvailable(true), () => _setAvailable(false));
    }
  }

  void _setAvailable(bool value) {
    if (_installAvailable == value) return;
    _installAvailable = value;
    notifyListeners();
  }

  /// Triggers the browser install prompt.
  Future<void> promptInstall() async {
    if (kIsWeb) {
      await pwa.pwaPromptInstall();
    }
  }

  /// Dismisses the install banner (user closed it).
  void dismissInstallBanner() => _setAvailable(false);
}