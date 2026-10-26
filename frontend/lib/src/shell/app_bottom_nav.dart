import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A single destination rendered by [AppBottomNav].
@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Icon shown while the destination is not selected.
  final IconData icon;

  /// Icon shown while the destination is selected.
  final IconData selectedIcon;

  /// Text label shown beneath the icon.
  final String label;
}

/// A bottom navigation bar whose middle destination is a raised circular
/// centerpiece.
///
/// Ported from the legacy web app's mobile nav, which renders a flat
/// full-width bar with a large circle floating above it. The "notch" is an
/// illusion rather than a real cutout: the unselected circle is filled with the
/// page background color and outlined with a hairline border, so it reads as a
/// hole punched through the bar.
///
/// The bar reserves [totalHeight] pixels of vertical space, of which the bottom
/// [barHeight] are the bar itself and the top [circleLift] are the strip the
/// circle rises into. Only the bar itself paints a background; the lift strip
/// is transparent so page content shows through it. Hosts should therefore set
/// `Scaffold.extendBody: true` and add [bottomInsetOf] to the bottom padding of
/// their scrollables so the last item still clears the bar.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  }) : assert(
         destinations.length >= 3,
         'AppBottomNav needs at least three destinations.',
       ),
       assert(
         destinations.length % 2 == 1,
         'AppBottomNav needs an odd number of destinations so that exactly '
         'one can be centered.',
       ),
       assert(
         selectedIndex >= 0 && selectedIndex < destinations.length,
         'selectedIndex must point at one of the destinations.',
       );

  /// Height of the flat bar itself, excluding the strip the circle rises into.
  static const double barHeight = 64;

  /// Diameter of the raised circular centerpiece.
  static const double circleDiameter = 72;

  /// How far the circle rises above the top edge of the bar.
  static const double circleLift = 12;

  /// Total vertical space the bar occupies, including the circle's lift.
  static const double totalHeight = barHeight + circleLift;

  /// The bottom padding a scrollable needs so its last item clears this bar.
  ///
  /// Returns [totalHeight] plus the device's bottom gesture inset. Reads
  /// [MediaQuery.viewPaddingOf] rather than `padding` on purpose: hosts use
  /// `Scaffold.extendBody`, which already inflates `padding.bottom` by the
  /// bar's height, so reading `padding` here would double-count it.
  static double bottomInsetOf(BuildContext context) {
    return totalHeight + MediaQuery.viewPaddingOf(context).bottom;
  }

  /// Index of the destination rendered as the raised circle.
  int get centerIndex => destinations.length ~/ 2;

  /// The index of the currently selected destination.
  final int selectedIndex;

  /// Called with the tapped destination's index.
  final ValueChanged<int> onDestinationSelected;

  /// The destinations to render, in order.
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor = isDark ? AppTheme.darkSurface : AppTheme.surface;
    final unselectedColor = isDark ? Colors.white70 : const Color(0xFF555555);
    final outlineColor = theme.colorScheme.outlineVariant;
    final holeColor = theme.scaffoldBackgroundColor;

    // Fill the gesture inset so the bar reaches the bottom of the screen.
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: totalHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // The flat bar, filling the bottom [barHeight] plus the gesture
          // inset. Its top border lands exactly [circleLift] below the top of
          // this widget; the strip above it is left transparent so page
          // content shows through.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight + bottomInset,
            child: DecoratedBox(
              key: const Key('nav-bar'),
              decoration: BoxDecoration(
                color: barColor,
                border: Border(top: BorderSide(color: outlineColor)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.40 : 0.06,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
          // The destinations, bottom-aligned with the bar's top edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: totalHeight,
            child: Row(
              children: <Widget>[
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: SizedBox(
                      height: totalHeight,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: i == centerIndex
                            ? _CenterNavItem(
                                destination: destinations[i],
                                selected: i == selectedIndex,
                                holeColor: holeColor,
                                outlineColor: outlineColor,
                                unselectedColor: unselectedColor,
                                onTap: () => _select(i),
                              )
                            // Side items center within the bar itself, not the
                            // strip the circle rises into.
                            : SizedBox(
                                height: barHeight,
                                child: _NavItem(
                                  destination: destinations[i],
                                  selected: i == selectedIndex,
                                  unselectedColor: unselectedColor,
                                  onTap: () => _select(i),
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _select(int index) {
    if (index == selectedIndex) return;
    HapticFeedback.selectionClick();
    onDestinationSelected(index);
  }
}

/// A regular (non-centered) destination: icon over label, with a soft pill
/// behind it while selected.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.unselectedColor,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.seed : unselectedColor;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.seed.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 24,
                    color: color,
                  ),
                  const SizedBox(height: 2),
                  // Shrinks the label to fit narrow slots instead of
                  // overflowing or truncating it.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised circular centerpiece.
///
/// Unselected it is filled with the page background color and outlined, which
/// makes it look like a hole punched through the bar. Selected it fills with a
/// vertical gradient and casts a colored glow.
class _CenterNavItem extends StatelessWidget {
  const _CenterNavItem({
    required this.destination,
    required this.selected,
    required this.holeColor,
    required this.outlineColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final Color holeColor;
  final Color outlineColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradientTop = Color.lerp(AppTheme.seed, Colors.white, 0.20)!;
    final gradientBottom = Color.lerp(AppTheme.seed, Colors.black, 0.30)!;
    final foreground = selected ? Colors.white : AppTheme.seed;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On very narrow screens the slot can be narrower than the circle;
          // shrink it rather than overflow.
          final diameter = constraints.maxWidth < AppBottomNav.circleDiameter
              ? constraints.maxWidth
              : AppBottomNav.circleDiameter;

          return Padding(
            // Keeps the circle's top edge exactly [circleLift] above the bar.
            padding: EdgeInsets.only(
              bottom:
                  AppBottomNav.barHeight + AppBottomNav.circleLift - diameter,
            ),
            child: AnimatedContainer(
              key: const Key('nav-center-circle'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? null : holeColor,
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[gradientTop, gradientBottom],
                      )
                    : null,
                border: Border.all(
                  color: selected ? Colors.transparent : outlineColor,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: selected
                        ? AppTheme.seed.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: selected ? 16 : 8,
                    offset: Offset(0, selected ? 6 : 2),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        size: 26,
                        color: foreground,
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected ? Colors.white : unselectedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
