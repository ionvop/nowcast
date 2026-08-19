import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';
import '../theme/app_theme.dart';
import '../utils/map_focus.dart';
import '../utils/time_ago.dart';
import 'user_avatar.dart';

/// A single post card in the community feed: author avatar, name, relative
/// time, content (clamped to 3 lines with ellipsis, line breaks preserved),
/// and an optional location address that opens the Map centered there.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;

  /// Called when the card is tapped. When null the card is not tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = post.user;
    final time = post.createdAt;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  UserAvatar(user: user, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user.name,
                          style: theme.textTheme.titleSmall,
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
              const SizedBox(height: 12),
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (post.address != null) ...<Widget>[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _openLocation(),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppTheme.seed,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            post.address!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.seed,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openLocation() {
    final lat = post.latitude;
    final lng = post.longitude;
    if (lat == null || lng == null) return;
    mapFocus.focusOn(LatLng(lat, lng));
  }
}
