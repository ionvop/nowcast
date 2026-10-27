import 'package:flutter/material.dart';

/// Visual tokens for the bevel, gradient and shadow treatment applied to
/// [AppCard] surfaces.
///
/// A card is painted as two stacked rounded rectangles: an outer "bevel ring"
/// whose gradient runs from a light top-left edge to a darker bottom-right
/// edge, and an inner face inset by [bevelWidth] that carries the surface
/// gradient. The ring is what produces the soft, machined bevel; the shadows
/// lift the whole thing off the background.
///
/// Flutter forbids a non-uniform [Border] on a [BoxDecoration] that also has a
/// [BorderRadius], which is why the bevel is expressed as a gradient ring
/// rather than per-side border colors.
@immutable
class CardStyle {
  const CardStyle({
    required this.bevelWidth,
    required this.surfaceGradient,
    required this.bevelGradient,
    required this.shadows,
  });

  /// Thickness of the bevel ring drawn around the card's face.
  final double bevelWidth;

  /// Gradient painted on the card's face.
  final Gradient surfaceGradient;

  /// Gradient painted on the bevel ring behind the face.
  final Gradient bevelGradient;

  /// Drop shadows that lift the card off the background.
  final List<BoxShadow> shadows;

  /// Bevel thickness used by every card. One logical pixel reads as a crisp
  /// edge without looking like a heavy outline.
  static const double bevelWidthValue = 1;

  static const Alignment _begin = Alignment.topLeft;
  static const Alignment _end = Alignment.bottomRight;

  /// Light-mode tokens: a white face fading to a barely-tinted blue, a white
  /// highlight on the top-left edge, and a soft two-layer shadow.
  static const CardStyle _light = CardStyle(
    bevelWidth: bevelWidthValue,
    surfaceGradient: LinearGradient(
      begin: _begin,
      end: _end,
      colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF5F9FF)],
    ),
    bevelGradient: LinearGradient(
      begin: _begin,
      end: _end,
      colors: <Color>[Color(0xFFFFFFFF), Color(0xFFD3DFF0)],
    ),
    shadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 16,
        spreadRadius: -2,
        offset: Offset(0, 6),
      ),
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
  );

  /// Dark-mode tokens: a slightly lighter face fading to near-black, a faint
  /// highlight on the top-left edge, and a deeper shadow.
  static const CardStyle _dark = CardStyle(
    bevelWidth: bevelWidthValue,
    surfaceGradient: LinearGradient(
      begin: _begin,
      end: _end,
      colors: <Color>[Color(0xFF262626), Color(0xFF1A1A1A)],
    ),
    bevelGradient: LinearGradient(
      begin: _begin,
      end: _end,
      colors: <Color>[Color(0xFF3C3C3C), Color(0xFF0D0D0D)],
    ),
    shadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 18,
        spreadRadius: -2,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
  );

  static const List<BoxShadow> _lightElevatedShadows = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      spreadRadius: -4,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> _darkElevatedShadows = <BoxShadow>[
    BoxShadow(
      color: Color(0x99000000),
      blurRadius: 26,
      spreadRadius: -4,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Returns the tokens for the current [Theme] brightness.
  ///
  /// Set [elevated] for surfaces that should sit noticeably higher than the
  /// rest of the page (e.g. the emergency button or map info cards).
  static CardStyle of(BuildContext context, {bool elevated = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? _dark : _light;
    if (!elevated) return base;
    return base.copyWith(
      shadows: isDark ? _darkElevatedShadows : _lightElevatedShadows,
    );
  }

  /// Returns tokens for a card painted in an arbitrary [color] or [gradient]
  /// instead of the default surface.
  ///
  /// The face gradient is derived by nudging the base color toward white at the
  /// top-left and toward black at the bottom-right, and the bevel ring uses
  /// stronger versions of the same nudges so the edge stays visible against
  /// saturated fills such as `colorScheme.primary` or `errorContainer`.
  static CardStyle forSurface(
    BuildContext context, {
    Color? color,
    Gradient? gradient,
    bool elevated = false,
  }) {
    final base = of(context, elevated: elevated);
    if (color == null && gradient == null) return base;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color light;
    final Color dark;
    if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
      light = gradient.colors.first;
      dark = gradient.colors.last;
    } else {
      light = color ?? Colors.white;
      dark = color ?? Colors.white;
    }

    return base.copyWith(
      surfaceGradient:
          gradient ??
          LinearGradient(
            begin: _begin,
            end: _end,
            colors: <Color>[
              Color.lerp(light, Colors.white, isDark ? 0.06 : 0.10)!,
              Color.lerp(dark, Colors.black, isDark ? 0.10 : 0.06)!,
            ],
          ),
      bevelGradient: LinearGradient(
        begin: _begin,
        end: _end,
        colors: <Color>[
          Color.lerp(light, Colors.white, isDark ? 0.18 : 0.55)!,
          Color.lerp(dark, Colors.black, isDark ? 0.35 : 0.22)!,
        ],
      ),
    );
  }

  /// Returns a copy of this style with the given fields replaced.
  CardStyle copyWith({
    double? bevelWidth,
    Gradient? surfaceGradient,
    Gradient? bevelGradient,
    List<BoxShadow>? shadows,
  }) {
    return CardStyle(
      bevelWidth: bevelWidth ?? this.bevelWidth,
      surfaceGradient: surfaceGradient ?? this.surfaceGradient,
      bevelGradient: bevelGradient ?? this.bevelGradient,
      shadows: shadows ?? this.shadows,
    );
  }
}
