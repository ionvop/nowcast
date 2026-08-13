import 'package:flutter/material.dart';

import '../widgets/placeholder_view.dart';

/// Post detail: shows a single community post with its author, time, content,
/// and location. Currently a non-functional placeholder.
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: const PlaceholderView(
        icon: Icons.article_outlined,
        title: 'Post Detail',
        description: 'A single community post with author, time, content, and '
            'location will appear here. Authors can delete their own posts.',
      ),
    );
  }
}