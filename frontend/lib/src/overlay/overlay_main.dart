import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../theme/app_theme.dart';
import 'activities_chat_panel.dart';

/// Entry point for the overlay engine (a separate Flutter isolate).
///
/// Registered in `main.dart` via `FlutterOverlayWindow.overlayListener` /
/// `FlutterOverlayWindow.isOverlayPermissionGranted` — the plugin invokes
/// `overlayMain` when the overlay window is shown. Must be annotated with
/// `@pragma("vm:entry-point")` so the AOT compiler keeps it.
@pragma('vm:entry-point')
void overlayMain() {
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
    final size = PlatformDispatcher.instance.views.first.physicalSize;
    final dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;
    await FlutterOverlayWindow.resizeOverlay(
      (size.width / dpr * 0.92).round(),
      (size.height / dpr * 0.72).round(),
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
class _Bubble extends StatelessWidget {
  const _Bubble({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.seed,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }
}
