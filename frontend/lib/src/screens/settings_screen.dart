import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import '../theme/app_theme.dart';

/// Settings page: currently just a dark-mode toggle (default is light mode).
///
/// Listens to the app-wide [settingsController] so the switch stays in sync
/// with the persisted preference and the applied theme.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settingsController,
        builder: (context, _) {
          final darkMode = settingsController.isDarkMode;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.dark_mode_outlined, color: AppTheme.seed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Dark mode',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Use a dark color scheme for the app.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: darkMode,
                        onChanged: (value) =>
                            settingsController.setDarkMode(value),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}