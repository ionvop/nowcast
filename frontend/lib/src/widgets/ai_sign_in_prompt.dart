import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import 'app_card.dart';
import 'sign_in_button.dart';

/// A card prompting a signed-out user to sign in before using a feature that
/// requires an account.
///
/// Shared by the Home page's AI block and the Heat Data page's health-risk
/// section so both gate their AI actions the same way.
class AiSignInPrompt extends StatelessWidget {
  const AiSignInPrompt({
    super.key,
    required this.auth,
    this.title = 'AI features',
    this.description =
        'Sign in with Google to generate AI summaries and use the floating '
        'AI bubble.',
    this.icon = Icons.auto_awesome,
  });

  /// The auth state to sign in with.
  final AuthController auth;

  /// The card's heading.
  final String title;

  /// The explanatory line under the heading.
  final String description;

  /// The icon shown beside the heading.
  final IconData icon;

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
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
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
