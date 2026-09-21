import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../utils/map_focus.dart';
import '../utils/time_ago.dart';
import '../widgets/comment_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/user_avatar.dart';

/// Post detail: shows a single community post with its author, time, content,
/// and location, plus its comments. The author can delete their own post, and
/// signed-in users can comment and delete their own comments.
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

  List<Comment> _comments = const <Comment>[];
  bool _commentsLoading = false;
  String? _commentError;
  final TextEditingController _commentController = TextEditingController();
  bool _commenting = false;

  /// Id of the comment currently being deleted, if any.
  int? _deletingCommentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

      await _loadComments(postId);
    } on ApiException catch (e) {
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while loading this post.');
    }
  }

  /// Loads the comments for the given post. Non-fatal: a failure leaves the
  /// post visible with an inline error and retry.
  Future<void> _loadComments(int postId) async {
    setState(() {
      _commentsLoading = true;
      _commentError = null;
    });
    try {
      final json = await _api.get('posts/$postId/comments');
      if (!mounted) return;
      setState(() {
        _comments = _parseComments(json);
        _commentsLoading = false;
      });
    } on ApiException catch (e) {
      _failComments(e.message);
    } on NetworkException catch (e) {
      _failComments(e.message);
    } on Exception {
      _failComments('Something went wrong while loading comments.');
    }
  }

  List<Comment> _parseComments(dynamic json) {
    if (json is! List) return const <Comment>[];
    return json
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
  }

  void _failComments(String message) {
    if (!mounted) return;
    setState(() {
      _commentError = message;
      _commentsLoading = false;
    });
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

  Future<void> _submitComment() async {
    final post = _post;
    if (post == null || post.id == null) return;

    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showSnack('Please write something before commenting.');
      return;
    }
    if (_commenting) return;

    setState(() => _commenting = true);
    try {
      final token = authController.token;
      if (token == null) {
        _showSnack('You need to sign in to comment.');
        return;
      }
      final json = await _api.post(
        'posts/${post.id}/comments',
        <String, dynamic>{'content': content},
        token: token,
      );
      if (!mounted) return;
      final comment = Comment.fromJson(
        json is Map<String, dynamic> ? json : <String, dynamic>{},
      );
      _commentController.clear();
      setState(() {
        _comments = <Comment>[comment, ..._comments];
        _commentError = null;
      });
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
      _showSnack('Something went wrong while commenting. Please try again.');
    } finally {
      if (mounted) setState(() => _commenting = false);
    }
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    if (comment.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This comment will be permanently removed.'),
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

    setState(() => _deletingCommentId = comment.id);
    try {
      final token = authController.token;
      if (token == null) {
        _showSnack('You need to sign in to delete this comment.');
        return;
      }
      await _api.delete('comments/${comment.id}', token: token);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((c) => c.id != comment.id).toList();
      });
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
      _showSnack('Something went wrong while deleting this comment.');
    } finally {
      if (mounted) setState(() => _deletingCommentId = null);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    // Close this detail screen so the user lands on the Map tab.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildPostCard(post, theme, user, time),
            const SizedBox(height: 16),
            _buildCommentsSection(post),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post, ThemeData theme, User user, DateTime? time) {
    return Card(
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(post.content, style: theme.textTheme.bodyLarge),
            if (post.address != null) ...<Widget>[
              const SizedBox(height: 16),
              InkWell(
                onTap: _openLocation,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.address!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
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
    );
  }

  Widget _buildCommentsSection(Post post) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Comments', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (authController.isAuthenticated) ...<Widget>[
              _buildCommentComposer(),
              const SizedBox(height: 12),
            ],
            _buildCommentsList(post),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentComposer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a comment…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.send),
          tooltip: 'Send comment',
          onPressed: _commenting ? null : _submitComment,
        ),
      ],
    );
  }

  Widget _buildCommentsList(Post post) {
    final theme = Theme.of(context);

    if (_commentsLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LoadingOverlay(label: 'Loading comments…'),
      );
    }
    if (_commentError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _commentError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _loadComments(post.id!),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No comments yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final comment in _comments)
          CommentCard(
            comment: comment,
            isOwner: comment.userId != null && comment.userId == _currentUserId,
            onDelete: _deletingCommentId == comment.id
                ? null
                : () => _confirmDeleteComment(comment),
          ),
      ],
    );
  }
}
