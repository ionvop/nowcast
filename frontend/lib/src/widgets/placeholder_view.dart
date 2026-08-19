import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A reusable placeholder body used by every screen in the app shell.
///
/// Renders a centered icon, a screen title, and a short description inside a
/// rounded white card on the light background. Screens will replace this
/// with real functionality later.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.body,
  });

  /// Icon shown at the top of the placeholder card.
  final IconData icon;

  /// Screen title shown inside the card.
  final String title;

  /// Short description of the screen's future purpose.
  final String description;

  /// Optional custom body rendered below the description.
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 64, color: AppTheme.seed),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF555555),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (body != null) ...<Widget>[
                    const SizedBox(height: 24),
                    body!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
