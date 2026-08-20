import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/placeholder_view.dart';
import '../widgets/post_card.dart';
import '../widgets/user_avatar.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';

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
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (!authController.isInitialized) {
          return Scaffold(
            appBar: _buildProfileAppBar(context, null),
            body: const LoadingOverlay(label: 'Loading…'),
          );
        }
        if (!authController.isAuthenticated) {
          return Scaffold(
            appBar: _buildProfileAppBar(context, null),
            body: const _SignInPrompt(),
          );
        }
        return _ProfileView(key: ValueKey(authController.token));
      },
    );
  }
}

/// Builds the Profile tab's top bar: a settings action and an optional
/// reload action. The reload action is only shown when [onReload] is
/// non-null.
AppBar _buildProfileAppBar(BuildContext context, VoidCallback? onReload) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
      },
    ),
    title: const Text('Profile'),
    actions: onReload == null
        ? const <Widget>[]
        : <Widget>[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: onReload,
            ),
          ],
  );
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
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
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

  /// The signed-in user's own posts, newest first.
  List<Post> _posts = const <Post>[];

  /// Whether the posts section is currently loading.
  bool _postsLoading = false;

  /// Non-fatal error while loading the posts section.
  String? _postsError;

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
      final user = User.fromJson(json as Map<String, dynamic>);
      setState(() {
        _user = user;
        _loading = false;
      });
      await _loadPosts(user);
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

  /// Loads the signed-in user's own posts. Failures are non-fatal: the
  /// profile card still renders and the posts section shows an error.
  Future<void> _loadPosts(User user) async {
    final userId = user.id;
    if (userId == null) return;

    setState(() {
      _postsLoading = true;
      _postsError = null;
    });

    try {
      final json = await _api.get('users/$userId/posts');
      if (!mounted) return;
      setState(() {
        _posts = _parsePosts(json);
        _postsLoading = false;
      });
    } on ApiException catch (e) {
      _postsFail(e.message);
    } on NetworkException catch (e) {
      _postsFail(e.message);
    } on Exception {
      _postsFail('Something went wrong while loading your posts.');
    }
  }

  List<Post> _parsePosts(dynamic json) {
    if (json is! List) return const <Post>[];
    return json
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();
  }

  void _postsFail(String message) {
    if (!mounted) return;
    setState(() {
      _postsError = message;
      _postsLoading = false;
    });
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

  Future<void> _openPost(Post post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    );
    // Refresh the posts after one is deleted from its detail view.
    final user = _user;
    if (changed == true && mounted && user != null) {
      _loadPosts(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildProfileAppBar(context, _loading ? null : _load),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ProfileCard(user: user, onSignOut: _signOut),
            const SizedBox(height: 24),
            _buildPostsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'My Posts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildPostsBody(),
      ],
    );
  }

  Widget _buildPostsBody() {
    if (_postsLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(width: 12),
            Text('Loading posts…'),
          ],
        ),
      );
    }
    if (_postsError != null) {
      return ErrorView(message: _postsError!, onRetry: () => _loadPosts(_user!));
    }
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              'No posts yet',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Posts you share with the community will appear here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final post in _posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: post,
              onTap: () => _openPost(post),
            ),
          ),
      ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            UserAvatar(user: user, radius: 48),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    );
  }
}