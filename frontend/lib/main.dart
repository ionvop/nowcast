import 'package:flutter/material.dart';

import 'src/auth/auth_controller.dart';
import 'src/overlay/activities_bubble_controller.dart';
import 'src/overlay/overlay_main.dart' show runOverlayApp;
import 'src/services/heat_alert_controller.dart';
import 'src/services/heat_alert_service.dart';
import 'src/services/settings_controller.dart';
import 'src/shell/app_shell.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore any stored token before the first frame so the shell can show the
  // correct signed-in / signed-out state immediately.
  await authController.init();
  // Configure the background service and auto-start it if the heat-alert
  // toggle was left on.
  await configureHeatAlertService();
  await heatAlertController.init();
  // Restore the stored theme preference before the first frame so the correct
  // light/dark theme is applied immediately.
  await settingsController.init();
  // When the user returns from the "Display over other apps" settings page,
  // show the bubble if the permission was granted in the meantime.
  AppLifecycleListener(onResume: ActivitiesBubbleController.instance.onAppResumed);
  runApp(const NowcastApp());
}

/// Entry point for the floating AI bubble's overlay engine.
///
/// `flutter_overlay_window` spawns a second Flutter engine and looks this
/// function up by name in the **root library** — it passes a null
/// `dartEntrypointLibrary` to `DartEntrypoint`, so the engine resolves it with
/// `Dart_GetField(Dart_RootLibrary(), "overlayMain")`. It therefore has to be
/// declared in this file; declaring it in another library makes the lookup
/// fail, and the overlay service then runs with no isolate and paints nothing.
///
/// The `@pragma('vm:entry-point')` annotation keeps the symbol alive in AOT
/// builds.
@pragma('vm:entry-point')
void overlayMain() => runOverlayApp();

/// Root widget for the Nowcast application.
class NowcastApp extends StatelessWidget {
  const NowcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Nowcast',
          theme: settingsController.isDarkMode
              ? AppTheme.dark()
              : AppTheme.light(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            // When no explicit time-format preference is stored, default to the
            // device's system time format. Applied after the frame so we don't
            // mutate controller state during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              settingsController.applyDeviceDefault(
                MediaQuery.alwaysUse24HourFormatOf(context),
              );
            });
            return child ?? const SizedBox.shrink();
          },
          home: const AppShell(),
        );
      },
    );
  }
}
