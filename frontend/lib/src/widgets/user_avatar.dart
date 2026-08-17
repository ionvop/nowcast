import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';

/// Circular avatar for a [User], decoding the base64 data URI returned by the
/// API and falling back to a themed placeholder when no avatar is available.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 24});

  final User user;

  /// Radius of the circular avatar in logical pixels.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeAvatar(user.avatar);
    if (bytes == null) return _fallback();
    return ClipOval(
      child: Image.memory(
        bytes,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _fallback(),
      ),
    );
  }

  Uint8List? _decodeAvatar(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) return null;
    const header = 'base64,';
    final comma = dataUri.indexOf(header);
    if (comma < 0) return null;
    try {
      return base64Decode(dataUri.substring(comma + header.length));
    } on FormatException {
      return null;
    }
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.seed.withValues(alpha: 0.12),
      child: Icon(Icons.person, size: radius, color: AppTheme.seed),
    );
  }
}
