import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> buildHeatMarker(Color color) =>
    buildHeatMarkerWithIcon(color, weatherIcon: null);

/// Builds the circular heat marker bitmap with an optional weather glyph
/// overlaid **inside** the circle.
///
/// Delegates to the base marker drawing and, when [weatherIcon] is non-null,
/// clips a badge region in the centre of the heat circle and composites the
/// glyph there, so the marker reads as a single coloured circle with a weather
/// condition on top. The caller owns [weatherIcon]; it is disposed here once
/// the bitmap has been rasterized.
///
/// [iconSize] is the intrinsic size of the decoded weather picture (from
/// `PictureInfo.size`); it is used to preserve the glyph's aspect ratio when
/// fitting it inside the badge.
Future<BitmapDescriptor> buildHeatMarkerWithIcon(
  Color color, {
  ui.Picture? weatherIcon,
  ui.Size iconSize = ui.Size.zero,
}) async {
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

  if (weatherIcon != null) {
    _drawIconInside(canvas, weatherIcon, iconSize, center, radius);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final descriptor =
      BitmapDescriptor.bytes(bytes!.buffer.asUint8List());

  picture.dispose();
  weatherIcon?.dispose();
  return descriptor;
}

/// Composites [icon] inside a circular badge drawn at [center] with [radius].
///
/// The glyph is bounded to a centred circle that fits within the heat fill
/// (roughly 62% of the marker radius, so it stays inside the border ring) and
/// drawn to preserve its aspect ratio. A translucent white disc is painted
/// behind the glyph as a subtle badge so the weather symbol stays legible
/// against saturated heat colors.
void _drawIconInside(
  ui.Canvas canvas,
  ui.Picture icon,
  ui.Size iconSize,
  Offset center,
  double radius,
) {
  final fillRadius = radius - 6.0;
  final badgeRadius = fillRadius * 0.62;

  // Circular clip so the glyph never bleeds outside the badge.
  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: center, radius: badgeRadius)),
  );

  // Translucent white disc behind the glyph to keep it legible on vivid heat
  // colors.
  canvas.drawCircle(
    center,
    badgeRadius,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );

  // Fit the glyph's intrinsic picture size inside the badge, preserving its
  // aspect ratio (contain).
  final glyphRect = Rect.fromCenter(
    center: center,
    width: badgeRadius * 2,
    height: badgeRadius * 2,
  );
  final srcWidth = iconSize.width > 0 ? iconSize.width : badgeRadius * 2;
  final srcHeight = iconSize.height > 0 ? iconSize.height : badgeRadius * 2;
  final scale = _fitScale(Size(srcWidth, srcHeight), glyphRect.size);

  canvas.translate(
    glyphRect.center.dx - (srcWidth / 2) * scale,
    glyphRect.center.dy - (srcHeight / 2) * scale,
  );
  canvas.scale(scale, scale);
  canvas.drawPicture(icon);
  canvas.restore();
}

/// Returns the uniform scale needed to fit [src] inside [dst], preserving
/// aspect ratio. Degenerates to 0 when [src] has a zero dimension.
double _fitScale(Size src, Size dst) {
  if (src.width <= 0 || src.height <= 0) {
    return 0;
  }
  return dst.shortestSide / src.shortestSide;
}

/// Builds the spinner bitmap shown while a tapped location is being analyzed.
Future<BitmapDescriptor> buildLoadingMarker() async {
  const size = 48.0;
  const center = Offset(size / 2, size / 2);
  // const radius = 20.0;

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