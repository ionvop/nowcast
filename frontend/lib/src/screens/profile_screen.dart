import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/placeholder_view.dart';
import 'login_screen.dart';

/// Profile tab: shows the signed-in user's avatar and name with a logout
/// option, or a sign-in prompt when logged out. Currently a non-functional
/// placeholder that always shows the logged-out state.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: const PlaceholderView(
        icon: Icons.person_outline,
        title: 'Sign In',
        description: 'Sign in with Google to view your profile and take part '
            'in the community.',
        body: _SignInButton(),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const LoginScreen(),
          ),
        );
      },
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Google'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.seed,
      ),
    );
  }
}