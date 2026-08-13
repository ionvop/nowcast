import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/placeholder_view.dart';

/// Login screen: the entry point for Google sign-in. Currently a
/// non-functional placeholder (the button does nothing yet).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: const PlaceholderView(
        icon: Icons.account_circle_outlined,
        title: 'Sign In with Google',
        description: 'Sign in securely with your Google account to post to the '
            'community and unlock profile features.',
        body: _GoogleSignInButton(),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        // TODO: trigger the Google OAuth flow once wired up.
      },
      icon: const Icon(Icons.login),
      label: const Text('Continue with Google'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.seed,
      ),
    );
  }
}