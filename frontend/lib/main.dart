import 'package:flutter/material.dart';

import 'src/shell/app_shell.dart';
import 'src/theme/app_theme.dart';

void main() {
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
