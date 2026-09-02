import 'package:flutter/material.dart';

import 'src/auth/auth_controller.dart';
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
  runApp(const NowcastApp());
}

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
