import 'package:flutter/material.dart';

import 'src/auth/auth_controller.dart';
import 'src/services/heat_alert_controller.dart';
import 'src/services/heat_alert_service.dart';
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
  runApp(const NowcastApp());
}

/// Root widget for the Nowcast application.
class NowcastApp extends StatelessWidget {
  const NowcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nowcast',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}
