import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/placeholder_view.dart';

/// Profile tab: shows the signed-in user's avatar and name with a logout
/// option, or a sign-in prompt when logged out.
///
/// The signed-in state is driven by [authController]; the login flow opens
/// the backend's Google consent URL in the external browser and receives the
/// token back via a deep-link fragment. When the profile endpoint returns a
/// 401 the stored token is cleared and the screen returns to the sign-in
/// prompt.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          if (!authController.isInitialized) {
            return const LoadingOverlay(label: 'Loading…');
          }
          if (!authController.isAuthenticated) {
            return const _SignInPrompt();
          }
          return _ProfileView(key: ValueKey(authController.token));
        },
      ),
    );
  }
}

/// Sign-in prompt shown when no valid token is stored.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  Future<void> _signIn(BuildContext context) async {
    try {
      await authController.signIn();
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the sign-in page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlaceholderView(
      icon: Icons.person_outline,
      title: 'Sign In',
      description: 'Sign in with Google to view your profile and take part '
          'in the community.',
      body: _SignInButton(onPressed: () => _signIn(context)),
    );
  }
}

/// Google sign-in button that opens the consent screen in the browser.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Google'),
      style: FilledButton.styleFrom(backgroundColor: AppTheme.seed),
    );
  }
}

/// Fetch-and-display layer for an authenticated user's profile.
class _ProfileView extends StatefulWidget {
  const _ProfileView({super.key});

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String? _error;
  User? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = authController.token;
    if (token == null) return;

    try {
      final json = await _api.get('profile', token: token);
      if (!mounted) return;
      setState(() {
        _user = User.fromJson(json as Map<String, dynamic>);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await authController.signOut();
        return;
      }
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    await authController.signOut();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingOverlay(label: 'Loading profile…');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final user = _user;
    if (user == null) {
      return const _SignInPrompt();
    }
    return _ProfileCard(
      user: user,
      onSignOut: _signOut,
    );
  }
}

/// The authenticated profile card: avatar, name, email and a logout button.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onSignOut});

  final User user;
  final VoidCallback onSignOut;

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
                  _Avatar(user: user),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF555555),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar image, decoding the base64 data URI returned by the API.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeAvatar(user.avatar);
    if (bytes == null) return _fallback();
    return ClipOval(
      child: Image.memory(
        bytes,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _fallback(),
      ),
    );
  }

  Uint8List? _decodeAvatar(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) return null;
    const header = 'base64,';
    final comma = dataUri.indexOf(header);
    if (comma < 0) return null;
    try {
      return base64Decode(dataUri.substring(comma + header.length));
    } on FormatException {
      return null;
    }
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: 48,
      backgroundColor: AppTheme.seed.withValues(alpha: 0.12),
      child: const Icon(Icons.person, size: 56, color: AppTheme.seed),
    );
  }
}