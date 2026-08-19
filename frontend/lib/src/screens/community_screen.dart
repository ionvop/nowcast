import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models/post.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/placeholder_view.dart';
import '../widgets/post_card.dart';
import 'new_post_screen.dart';
import 'post_detail_screen.dart';

/// Community tab: a feed of user posts shown newest-first, plus a floating
/// "New Post" action shown only when signed in.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String? _error;
  List<Post> _posts = const <Post>[];

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

    try {
      final json = await _api.get('posts');
      if (!mounted) return;
      setState(() {
        _posts = _parsePosts(json);
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while loading the community feed.');
    }
  }

  List<Post> _parsePosts(dynamic json) {
    if (json is! List) return const <Post>[];
    return json
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  Future<void> _openNewPost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const NewPostScreen(),
      ),
    );
    // Refresh the feed after a post is created.
    if (created == true && mounted) {
      _load();
    }
  }

  Future<void> _openPost(Post post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    );
    // Refresh the feed after a post is deleted from its detail view.
    if (changed == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          if (!authController.isAuthenticated) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: _openNewPost,
            icon: const Icon(Icons.add),
            label: const Text('New Post'),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingOverlay(label: 'Loading community…');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_posts.isEmpty) {
      return const PlaceholderView(
        icon: Icons.forum_outlined,
        title: 'Community Feed',
        description: 'No posts yet. Signed-in users can share their current '
            'conditions with the community.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: post,
              onTap: () => _openPost(post),
            ),
          );
        },
      ),
    );
  }
}