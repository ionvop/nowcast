import 'package:flutter/material.dart';

import '../overlay/activities_bubble_controller.dart';
import 'app_card.dart';

/// Card with a toggle for the floating AI activities bubble (Android only).
///
/// The bubble is drawn over other apps by a separate overlay engine; the
/// first activation routes the user to the system "Display over other apps"
/// settings when the permission has not been granted yet.
///
/// Callers are responsible for only rendering this on Android — the
/// `flutter_overlay_window` plugin has no iOS/web implementation.
class BubbleToggleCard extends StatelessWidget {
  const BubbleToggleCard({super.key, this.controller});

  /// Injectable controller for tests. Defaults to the app-wide singleton.
  final ActivitiesBubbleController? controller;

  Future<void> _toggle(
    BuildContext context,
    ActivitiesBubbleController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await controller.toggle();
    switch (result) {
      case BubbleToggleResult.shown:
      case BubbleToggleResult.hidden:
        return;
      case BubbleToggleResult.permissionDenied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Grant Nowcast "Display over other apps" permission to show the '
              'floating bubble.',
            ),
          ),
        );
      case BubbleToggleResult.failed:
        // The AOSP permission is granted but the window never appeared. On
        // MIUI/HyperOS (and some other vendor ROMs) a second, non-standard
        // permission gates overlay windows and `canDrawOverlays()` does not
        // report it.
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text(
              'The bubble could not be shown. On Xiaomi/HyperOS, also enable '
              'App info → Other permissions → "Display pop-up windows while '
              'running in background", and set battery saver to "No '
              'restrictions".',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? ActivitiesBubbleController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.isActive;
        return AppCard(
          child: ListTile(
            leading: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Floating AI bubble'),
            subtitle: Text(
              active
                  ? 'Showing over other apps. Tap to hide.'
                  : 'Show a floating bubble with AI activity suggestions '
                      'over other apps.',
            ),
            trailing: Switch(
              value: active,
              onChanged: (_) => _toggle(context, controller),
            ),
          ),
        );
      },
    );
  }
}
