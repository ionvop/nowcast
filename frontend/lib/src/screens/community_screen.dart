import 'package:flutter/material.dart';

import '../widgets/placeholder_view.dart';
import 'new_post_screen.dart';

/// Community tab: a feed of user posts shown newest-first, plus a floating
/// "New Post" action. Currently a non-functional placeholder.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: const PlaceholderView(
        icon: Icons.forum_outlined,
        title: 'Community Feed',
        description: 'Posts from the community will appear here, newest '
            'first. Signed-in users can share their current conditions.',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const NewPostScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
      ),
    );
  }
}