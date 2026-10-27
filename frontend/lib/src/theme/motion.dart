import 'package:flutter/animation.dart';

/// Shared timing and geometry for the app's entrance animations.
///
/// Cards fade and slide into view when they scroll into the viewport. Items
/// that become visible in the same frame are staggered so they appear in
/// sequence rather than all at once.
abstract final class AppMotion {
  /// How long a single card takes to fade and slide into place.
  static const Duration revealDuration = Duration(milliseconds: 320);

  /// The gap between consecutive cards revealed in the same batch.
  static const Duration staggerStep = Duration(milliseconds: 70);

  /// The largest delay any card receives, so long lists stay responsive.
  static const Duration staggerMax = Duration(milliseconds: 350);

  /// How far a card travels, in logical pixels, while fading in.
  static const double revealOffset = 24;

  /// The easing applied to the fade and slide.
  static const Curve revealCurve = Curves.easeOutCubic;
}
