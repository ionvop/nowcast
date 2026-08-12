import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Circular avatar that renders a base64 data-URI image if present, otherwise
/// a placeholder icon with the person's initial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.name, this.avatar, this.radius = 20});

  final String? name;
  final String? avatar;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final a = avatar;
    if (a != null && a.startsWith('data:')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(_decodeDataUri(a)),
      );
    }
    final initial = (name == null || name!.isEmpty)
        ? '?'
        : name![0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF00AAFF),
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontSize: radius * 0.8),
      ),
    );
  }

  Uint8List _decodeDataUri(String dataUri) {
    final comma = dataUri.indexOf(',');
    final base64 = comma >= 0 ? dataUri.substring(comma + 1) : dataUri;
    return base64Decode(base64);
  }
}
