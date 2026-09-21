import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/user.dart';

/// Builds the circular community-post marker bitmap: a white-outline circle
/// (mirroring the heat marker) with the author's avatar composited inside.
///
/// The avatar is a base64-encoded JPEG/PNG data URI (see [User.avatar]); it is
/// decoded into a [ui.Image] and drawn (cover) inside a circular badge clipped
/// to the marker's fill. When the author has no avatar, or the bytes cannot be
/// decoded, a neutral person glyph is drawn instead so the marker stays
/// legible.
Future<BitmapDescriptor> buildPostMarker(User user) async {
  const scale = 2.0;
  const size = 48.0; // 24dp * 2
  const center = Offset(size / 2, size / 2);
  const radius = 20.0; // 10dp * 2 → 20dp diameter
  const border = 6.0; // 3dp * 2

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Drop shadow.
  canvas.drawCircle(
    center + const Offset(0, 2 * scale),
    radius,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * scale),
  );

  // White border ring.
  canvas.drawCircle(center, radius, Paint()..color = Colors.white);

  // Fill (neutral, so the avatar reads clearly against the ring).
  final fillRadius = radius - border / 2;
  canvas.drawCircle(
    center,
    fillRadius,
    Paint()..color = Colors.white,
  );

  // Avatar badge, clipped to the fill.
  final badgeRadius = fillRadius - 2.0;
  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: center, radius: badgeRadius)),
  );

  final avatarBytes = _decodeAvatarBytes(user.avatar);
  final image = avatarBytes != null ? await _decodeImage(avatarBytes) : null;
  if (image != null) {
    _drawAvatarCover(canvas, image, center, badgeRadius);
    image.dispose();
  } else {
    _drawPersonGlyph(canvas, center, badgeRadius);
  }

  canvas.restore();

  final picture = recorder.endRecording();
  final raster = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
  final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());

  picture.dispose();
  return descriptor;
}

/// Decodes [dataUri] (a `data:image/...;base64,...` string) into raw bytes, or
/// null when it is missing or malformed. Mirrors `UserAvatar._decodeAvatar`.
Uint8List? _decodeAvatarBytes(String? dataUri) {
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

/// Decodes [bytes] into a [ui.Image], or null on failure.
Future<ui.Image?> _decodeImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } on Exception {
    return null;
  }
}

/// Draws [image] to fill the circle at [center] with [radius], preserving
/// aspect ratio (cover) and centering the crop.
void _drawAvatarCover(
  ui.Canvas canvas,
  ui.Image image,
  Offset center,
  double radius,
) {
  final diameter = radius * 2;
  final srcWidth = image.width.toDouble();
  final srcHeight = image.height.toDouble();
  if (srcWidth <= 0 || srcHeight <= 0) return;

  // Compute the source crop that, scaled to the badge, covers it exactly.
  final scale = diameter / (srcWidth < srcHeight ? srcWidth : srcHeight);
  final dstWidth = srcWidth * scale;
  final dstHeight = srcHeight * scale;

  final srcRect = Rect.fromLTWH(0, 0, srcWidth, srcHeight);
  final dstRect = Rect.fromCenter(
    center: center,
    width: dstWidth,
    height: dstHeight,
  );
  canvas.drawImageRect(image, srcRect, dstRect, Paint());
}

/// Draws a neutral person glyph (head + shoulders) centered at [center] with
/// [radius], used when the author has no avatar.
void _drawPersonGlyph(ui.Canvas canvas, Offset center, double radius) {
  final paint = Paint()..color = const Color(0xFF9E9E9E);

  // Head.
  canvas.drawCircle(
    center + Offset(0, -radius * 0.28),
    radius * 0.30,
    paint,
  );

  // Shoulders.
  final shoulders = Path()
    ..moveTo(center.dx - radius * 0.62, center.dy + radius * 0.95)
    ..quadraticBezierTo(
      center.dx,
      center.dy + radius * 0.30,
      center.dx + radius * 0.62,
      center.dy + radius * 0.95,
    )
    ..close();
  canvas.drawPath(shoulders, paint);
}