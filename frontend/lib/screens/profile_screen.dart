import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/adapters/oauth_return_adapter.dart';
import '../core/api_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/alert_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/user_avatar.dart';

/// Profile tab: Google sign-in / logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _oauth = OAuthReturnAdapter();

  bool _initialized = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // On web, check for an OAuth callback fragment on first build.
    if (kIsWeb) {
      _handleWebOAuthFragment();
    }
  }

  Future<void> _handleWebOAuthFragment() async {
    final app = context.read<AppState>();
    final params = _oauth.readFragment();
    if (params == null) {
      // No callback; ensure user is loaded from profile if signed in.
      if (app.auth.isSignedIn && app.auth.user == null) {
        await _loadProfile();
      }
      if (mounted) setState(() => _initialized = true);
      return;
    }

    setState(() => _loading = true);
    if (params.containsKey('error')) {
      setState(() {
        _loading = false;
        _initialized = true;
        _error = 'Sign-in failed. Please try again.';
      });
      return;
    }
    final token = params['token'];
    if (token != null && token.isNotEmpty) {
      app.auth.setToken(token);
      await _loadProfile();
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _initialized = true;
      });
    }
  }

  Future<void> _loadProfile() async {
    final app = context.read<AppState>();
    final api = app.api;
    try {
      final json = await api.get('/profile');
      if (!mounted) return;
      final map = json is Map
          ? Map<String, dynamic>.from(json)
          : <String, dynamic>{};
      app.auth.setUser(User.fromJson(map));
    } on ApiAuthException {
      if (mounted) await app.auth.clear();
    } on ApiException {
      // Keep signed-in state; profile fetch will retry.
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!kIsWeb) {
      // Native OAuth is handled in Phase 8 via deep links.
      await showAppAlert(
        context,
        message: 'Native sign-in is not available on this build yet.',
      );
      return;
    }

    final base = Uri.base;
    final returnTo = base.toString();
    final scheme = base.scheme;
    final host = base.hasPort
        ? '${base.host}:${base.port}'
        : base.host;
    final redirect = Uri.parse(
      '$scheme://$host${base.path}api/auth/google/redirect',
    ).replace(queryParameters: {'returnTo': returnTo});

    final launched = await launchUrl(
      redirect,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      await showAppAlert(
        context,
        message: 'Could not open the Google sign-in page.',
      );
    }
  }

  Future<void> _logout() async {
    final app = context.read<AppState>();
    final api = app.api;
    try {
      await api.post('/logout');
    } catch (_) {
      // Ignore logout network errors; still clear locally.
    }
    if (!mounted) return;
    await app.auth.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final auth = app.auth;
    final user = auth.user;

    if (_loading) {
      return const LoadingOverlay(label: 'Signing you in...');
    }
    if (!_initialized && kIsWeb) {
      return const SizedBox.shrink();
    }

    if (!auth.isSignedIn || user == null) {
      return _buildSignedOut();
    }
    return _buildSignedIn(user);
  }

  Widget _buildSignedOut() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 64, color: Color(0xFF555555)),
            const SizedBox(height: 16),
            const Text(
              'Sign in to post and contribute to Nowcast.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF555555)),
            ),
            const SizedBox(height: 24),
            _GoogleSignInButton(onPressed: _signInWithGoogle),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignedIn(User user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(name: user.name, avatar: user.avatar, radius: 40),
            const SizedBox(height: 16),
            Text(
              user.name ?? 'Unknown',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (user.email != null) ...[
              const SizedBox(height: 4),
              Text(
                user.email!,
                style: const TextStyle(color: Color(0xFF555555)),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Official Google-branded "Sign in with Google" button.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const _GoogleLogo(),
      label: const Text(
        'Sign in with Google',
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Color(0xFFDADCE0)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

/// Minimal 4-color Google "G" glyph rendered as a blue-bordered "G".
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF4285F4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          height: 1,
        ),
      ),
    );
  }
}