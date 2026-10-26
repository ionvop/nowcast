import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../overlay/activities_bubble_controller.dart';
import 'ai_summary_section.dart';
import 'bubble_toggle_card.dart';
import 'sign_in_button.dart';

/// The Home tab's AI block: the AI summary card plus, on Android, the toggle
/// for the floating AI activities bubble.
///
/// Both features are gated to signed-in users. When no token is stored the
/// block collapses to a single sign-in prompt so the Home page never offers an
/// AI action that would fail.
class AiFeaturesSection extends StatelessWidget {
  const AiFeaturesSection({
    super.key,
    required this.currentConditions,
    this.hourlyForecast,
    this.dailyForecast,
    this.api,
    this.auth,
    this.bubbleController,
  });

  /// The raw Google current-conditions payload (see API §5.1).
  final Map<String, dynamic> currentConditions;

  /// The raw Google hourly forecast payload (see API §5.2). Optional.
  final Map<String, dynamic>? hourlyForecast;

  /// The raw Google daily forecast payload (see API §5.3). Optional.
  final Map<String, dynamic>? dailyForecast;

  /// Injectable client for tests, forwarded to [AiSummarySection].
  final ApiClient? api;

  /// Injectable auth state for tests. Defaults to the app-wide singleton.
  final AuthController? auth;

  /// Injectable bubble controller for tests. Defaults to the app-wide
  /// singleton.
  final ActivitiesBubbleController? bubbleController;

  @override
  Widget build(BuildContext context) {
    final auth = this.auth ?? authController;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.isAuthenticated) {
          return _AiSignInPrompt(auth: auth);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AiSummarySection(
              currentConditions: currentConditions,
              hourlyForecast: hourlyForecast,
              dailyForecast: dailyForecast,
              api: api,
            ),
            // The overlay window plugin is Android-only.
            if (defaultTargetPlatform == TargetPlatform.android) ...<Widget>[
              const SizedBox(height: 16),
              BubbleToggleCard(controller: bubbleController),
            ],
          ],
        );
      },
    );
  }
}

/// Card prompting a signed-out user to sign in before using the AI features.
class _AiSignInPrompt extends StatelessWidget {
  const _AiSignInPrompt({required this.auth});

  final AuthController auth;

  Future<void> _signIn(BuildContext context) async {
    try {
      await auth.signIn();
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the sign-in page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI features',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in with Google to generate AI summaries and use the '
              'floating AI bubble.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SignInButton(onPressed: () => _signIn(context)),
          ],
        ),
      ),
    );
  }
}
