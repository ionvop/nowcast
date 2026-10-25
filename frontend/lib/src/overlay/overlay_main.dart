import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../theme/app_theme.dart';
import 'activities_chat_panel.dart';
import 'heat_bubble.dart';

/// Boots the overlay engine's widget tree (a separate Flutter isolate).
///
/// This must be called from `overlayMain` in `lib/main.dart`, not directly:
/// `flutter_overlay_window` resolves the entry point with
/// `Dart_GetField(Dart_RootLibrary(), "overlayMain")`, so the function has to
/// be a top-level member of the root library. A function declared here would
/// not be found and the overlay engine would start with no running isolate —
/// the service starts, but nothing is ever painted.
void runOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

/// Root widget of the overlay engine.
class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _OverlayHome(),
    );
  }
}

/// Hosts the bubble / chat panel and toggles between them.
///
/// The overlay window is created full-cover and transparent; the widget tree
/// decides how much of it is actually painted. The bubble state paints a
/// small draggable circle; the expanded state paints the chat panel.
class _OverlayHome extends StatefulWidget {
  const _OverlayHome();

  @override
  State<_OverlayHome> createState() => _OverlayHomeState();
}

class _OverlayHomeState extends State<_OverlayHome> {
  /// Whether the chat panel is expanded (vs. the compact bubble).
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // The main app can poke the overlay (e.g. to collapse the panel).
    FlutterOverlayWindow.overlayListener.listen((_) {
      if (!mounted) return;
      setState(() => _expanded = false);
    });
  }

  /// Expands the overlay window to fit the chat panel.
  Future<void> _expand() async {
    setState(() => _expanded = true);
    // Give the panel room: resize the overlay window to most of the screen.
    // `getScreenSize()` reports dp and works inside the overlay isolate, where
    // `MediaQuery` and `PlatformDispatcher.instance.views` are unreliable.
    final size = await FlutterOverlayWindow.getScreenSize();
    await FlutterOverlayWindow.resizeOverlay(
      (size.x * 0.92).round(),
      (size.y * 0.72).round(),
      false,
    );
  }

  /// Collapses the overlay window back to the compact bubble.
  Future<void> _collapse() async {
    setState(() => _expanded = false);
    await FlutterOverlayWindow.resizeOverlay(_bubbleSize, _bubbleSize, true);
  }

  static const int _bubbleSize = 56;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: _expanded
          ? ActivitiesChatPanel(
              onMinimize: _collapse,
              onClose: () async {
                await _collapse();
                // Tell the main app the bubble is gone so its button state
                // stays in sync.
                await FlutterOverlayWindow.shareData({'event': 'closed'});
                await FlutterOverlayWindow.closeOverlay();
              },
            )
          : _Bubble(onTap: _expand),
    );
  }
}

/// The compact draggable bubble shown over other apps.
///
/// The visual is a [HeatBubble], which reflects the current heat index and
/// weather for the user's location (falling back to the blue AI circle when
/// no reading is available).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: const HeatBubble(size: 56));
  }
}
