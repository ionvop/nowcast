import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/map_focus.dart';
import '../utils/time_ago.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/user_avatar.dart';

/// Post detail: shows a single community post with its author, time, content,
/// and location. The author can delete their own post.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, this.postId});

  /// The post's database id. When null the post is loaded from the passed
  /// [post] instead (used by tests).
  final int? postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String? _error;
  Post? _post;
  bool _deleting = false;

  /// The signed-in user's id, used to decide whether to show Delete.
  int? _currentUserId;

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

    final postId = widget.postId;
    if (postId == null) {
      _fail('This post is no longer available.');
      return;
    }

    try {
      final json = await _api.get('posts/$postId');
      if (!mounted) return;
      final post = Post.fromJson(
        json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      // Determine the signed-in user's id (for owner-only delete).
      int? currentUserId;
      final token = authController.token;
      if (token != null) {
        try {
          final profileJson = await _api.get('profile', token: token);
          if (profileJson is Map<String, dynamic>) {
            currentUserId = User.fromJson(profileJson).id;
          }
        } on ApiException catch (e) {
          if (e.statusCode == 401) {
            await authController.signOut();
          }
        } on Exception {
          // Non-fatal: the post still renders, just without a Delete button.
        }
      }

      if (!mounted) return;
      setState(() {
        _post = post;
        _currentUserId = currentUserId;
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while loading this post.');
    }
  }

  bool get _isOwner =>
      _post?.user.id != null && _post!.user.id == _currentUserId;

  Future<void> _confirmDelete() async {
    final post = _post;
    if (post == null || post.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This post will be permanently removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final token = authController.token;
      if (token == null) {
        _showSnack('You need to sign in to delete this post.');
        return;
      }
      await _api.delete('posts/${post.id}', token: token);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await authController.signOut();
        if (!mounted) return;
        _showSnack('Your session expired. Please sign in again.');
        return;
      }
      _showSnack(e.message);
    } on NetworkException catch (e) {
      _showSnack(e.message);
    } on Exception {
      _showSnack('Something went wrong while deleting this post.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _openLocation() {
    final post = _post;
    if (post == null) return;
    final lat = post.latitude;
    final lng = post.longitude;
    if (lat == null || lng == null) return;
    mapFocus.focusOn(LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingOverlay(label: 'Loading post…');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final post = _post;
    if (post == null) {
      return const ErrorView(message: 'This post is no longer available.');
    }

    final theme = Theme.of(context);
    final user = post.user;
    final time = post.createdAt;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UserAvatar(user: user, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (time != null)
                            Text(
                              timeAgo(time),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF555555),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  post.content,
                  style: theme.textTheme.bodyLarge,
                ),
                if (post.address != null) ...<Widget>[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _openLocation,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppTheme.seed,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              post.address!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.seed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_isOwner) ...<Widget>[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _deleting ? null : _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete post'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}