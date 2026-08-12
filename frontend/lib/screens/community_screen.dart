import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/user_avatar.dart';
import 'map_screen.dart';
import 'new_post_screen.dart';
import 'post_detail_screen.dart';

/// Community tab: list of posts, newest first, with New Post entry.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _loading = false;
  CancelToken? _cancelToken;
  List<Post> _posts = const [];
  String? _error;
  bool _signedIn = false;

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
    final app = context.read<AppState>();
    final api = app.api;
    _cancelToken?.cancel();
    final cancel = CancelToken();
    _cancelToken = cancel;

    setState(() {
      _loading = true;
      _error = null;
      _signedIn = app.auth.isSignedIn;
    });

    try {
      // Determine signed-in state (for the New Post FAB).
      if (app.auth.isSignedIn) {
        try {
          final profileJson = await api.get('/profile', cancelToken: cancel);
          if (!mounted || cancel.isCancelled) return;
          final map = profileJson is Map
              ? Map<String, dynamic>.from(profileJson)
              : <String, dynamic>{};
          final user = User.fromJson(map);
          app.auth.setUser(user);
          setState(() => _signedIn = true);
        } on ApiAuthException {
          setState(() => _signedIn = false);
        }
      }

      final postsJson = await api.get('/posts', cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      final list = postsJson is List ? postsJson : const [];
      final posts = list
          .whereType<Map>()
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() => _posts = posts);
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

  Future<void> _openNewPost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewPostScreen()),
    );
    if (created == true && mounted) {
      _load();
    }
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    ).then((deleted) {
      if (deleted == true && mounted) _load();
    });
  }

  void _openMap(double lat, double lng) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          targetLat: lat,
          targetLng: lng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ..._buildContent(),
          if (_loading) const LoadingOverlay(label: 'Loading posts...'),
        ],
      ),
      floatingActionButton: _signedIn
          ? FloatingActionButton(
              onPressed: _openNewPost,
              tooltip: 'New Post',
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  List<Widget> _buildContent() {
    if (_loading) return const [];
    if (_error != null) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF555555)),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    if (_posts.isEmpty) {
      return [
        const Center(
          child: Text(
            'No posts yet. Be the first to share!',
            style: TextStyle(color: Color(0xFF555555)),
          ),
        ),
      ];
    }
    return [
      RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: _posts.length,
          itemBuilder: (context, i) {
            final post = _posts[i];
            return _PostCard(
              post: post,
              onTap: () => _openPost(post),
              onLocationTap: (lat, lng) => _openMap(lat, lng),
            );
          },
        ),
      ),
    ];
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onTap,
    required this.onLocationTap,
  });

  final Post post;
  final VoidCallback onTap;
  final void Function(double lat, double lng) onLocationTap;

  @override
  Widget build(BuildContext context) {
    final user = post.user;
    final createdAt = post.createdDateTime;
    final ts = createdAt == null ? null : createdAt.millisecondsSinceEpoch ~/ 1000;
    final address = post.address;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(name: user?.name, avatar: user?.avatar),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 10),
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4),
              ),
              if (address != null && address.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    if (post.latitude != null && post.longitude != null) {
                      onLocationTap(post.latitude!, post.longitude!);
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
                          address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00AAFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}