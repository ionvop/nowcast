import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../utils/time_ago.dart';
import 'user_avatar.dart';

/// A single comment on a post: author avatar, name, relative time, and
/// content. When the signed-in user owns the comment, a delete action is
/// shown.
class CommentCard extends StatelessWidget {
  const CommentCard({
    super.key,
    required this.comment,
    this.isOwner = false,
    this.onDelete,
  });

  final Comment comment;

  /// Whether the signed-in user is the author of this comment, which shows
  /// the delete action.
  final bool isOwner;

  /// Called when the delete action is tapped. When null the action is hidden.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = comment.user;
    final time = comment.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatar(user: user, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        user.name,
                        style: theme.textTheme.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                const SizedBox(height: 4),
                Text(comment.content, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (isOwner && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete comment',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
