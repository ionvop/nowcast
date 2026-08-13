import 'package:flutter/material.dart';

/// A full-page loading overlay with a spinner and a progress label.
///
/// Shown while a page loads; the [label] updates as each sequential step
/// completes (e.g. "Loading geolocation... (1/4)").
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF555555),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
