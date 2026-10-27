import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/card_style.dart';

/// A card with a pronounced machined bevel edge, a diagonal background
/// gradient and a drop shadow, so it reads as a raised surface floating above
/// the page instead of a flat rectangle stuck to it.
///
/// Drop-in replacement for [Card]: the default [margin] and [borderRadius]
/// match the app's previous `CardThemeData`, so swapping one for the other
/// does not shift layout.
///
/// ```dart
/// AppCard(
///   onTap: () => openPost(post),
///   child: Padding(padding: EdgeInsets.all(16), child: content),
/// )
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 16,
    this.color,
    this.gradient,
    this.onTap,
    this.elevated = false,
  });

  /// The card's content.
  final Widget child;

  /// Space around the card. Defaults to the app's previous card margin.
  final EdgeInsetsGeometry margin;

  /// Corner radius of the card's outer edge.
  final double borderRadius;

  /// Base fill color. When set, the face gradient and bevel are derived from
  /// it instead of the default surface tokens.
  final Color? color;

  /// Explicit face gradient. When set, it is used as-is and the bevel is
  /// derived from its first and last colors.
  final Gradient? gradient;

  /// Called when the card is tapped. When null the card is not tappable.
  final VoidCallback? onTap;

  /// Whether to use the stronger shadow reserved for surfaces that should sit
  /// noticeably higher than the rest of the page.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final style = CardStyle.forSurface(
      context,
      color: color,
      gradient: gradient,
      elevated: elevated,
    );
    final outerRadius = BorderRadius.circular(borderRadius);
    final innerRadius = BorderRadius.circular(
      math.max(0, borderRadius - style.bevelWidth),
    );

    Widget content = child;
    if (onTap != null) {
      // A transparent Material hosts the ink splash so it paints above the
      // gradient face; InkWell's borderRadius clips the splash to the corners.
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: innerRadius,
          child: content,
        ),
      );
    }

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          gradient: style.bevelGradient,
          boxShadow: style.shadows,
        ),
        child: Padding(
          padding: EdgeInsets.all(style.bevelWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: innerRadius,
              gradient: style.surfaceGradient,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
