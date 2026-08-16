import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds the circular heat marker bitmap used on the map: 20px diameter,
/// white 3px border, drop shadow, filled with [color].
///
/// Rendered at 2x pixel density so it appears crisp on high-DPI screens
/// while still measuring ~20 logical px.
Future<BitmapDescriptor> buildHeatMarker(Color color) async {
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

  // Heat-index fill.
  canvas.drawCircle(
    center,
    radius - border / 2,
    Paint()..color = color,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Builds the spinner bitmap shown while a tapped location is being analyzed.
Future<BitmapDescriptor> buildLoadingMarker() async {
  const size = 48.0;
  const center = Offset(size / 2, size / 2);
  const radius = 20.0;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Concentric "pulse" rings: nested circles suggest a radar ping, reading as
  // "actively scanning this spot" even though the marker bitmap is static.
  for (final r in <double>[20.0, 13.0, 6.0]) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF00AAFF).withValues(alpha: 0.6),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}