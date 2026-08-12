import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/alert_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/user_avatar.dart';
import 'map_screen.dart';

/// Post Detail screen: single post, delete if owned by current user.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  CancelToken? _cancelToken;
  Post? _post;
  bool _loading = false;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    _cancelToken?.cancel();
    final cancel = CancelToken();
    _cancelToken = cancel;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final json = await api.get('/posts/${widget.postId}', cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
      setState(() => _post = Post.fromJson(map));
    } on ApiCancelledException {
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  bool _isAuthor() {
    final post = _post;
    final user = context.read<AppState>().auth.user;
    return post != null && user != null && post.user?.id == user.id;
  }

  Future<void> _delete() async {
    final api = context.read<AppState>().api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete post?'),
        content: const Text(
          'Are you sure you want to delete this post?',
          style: TextStyle(color: Color(0xFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await api.delete('/posts/${widget.postId}');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiAuthException {
      if (!mounted) return;
      setState(() => _deleting = false);
      await showAppAlert(context, message: 'You need to sign in to delete.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      await showAppAlert(context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      await showAppAlert(
        context,
        message: 'Could not delete the post. Please try again.',
      );
    }
  }

  void _openMap(double lat, double lng) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(targetLat: lat, targetLng: lng),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Stack(
        children: [
          _buildContent(),
          if (_loading) const LoadingOverlay(label: 'Loading post...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const SizedBox.shrink();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF555555)),
          ),
        ),
      );
    }
    final post = _post;
    if (post == null) return const SizedBox.shrink();
    final user = post.user;
    final createdAt = post.createdDateTime;
    final ts = createdAt == null ? null : createdAt.millisecondsSinceEpoch ~/ 1000;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: user?.name, avatar: user?.avatar, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      ts != null ? timeAgo(ts) : '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(post.content, style: const TextStyle(height: 1.5)),
          if (post.address != null && post.address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                if (post.latitude != null && post.longitude != null) {
                  _openMap(post.latitude!, post.longitude!);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Color(0xFF00AAFF)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      post.address!,
                      style: const TextStyle(
                        color: Color(0xFF00AAFF),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_isAuthor())
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}