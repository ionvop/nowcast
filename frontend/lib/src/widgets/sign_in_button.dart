import 'package:flutter/material.dart';

/// Google sign-in button that opens the consent screen in the browser.
///
/// Shared by the Profile tab's sign-in prompt and the Home tab's AI features
/// prompt so both entry points look and behave identically.
class SignInButton extends StatelessWidget {
  const SignInButton({super.key, required this.onPressed});

  /// Called when the button is tapped; typically `authController.signIn()`.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Google'),
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
