import 'package:flutter/material.dart';

import '../screens/community_screen.dart';
import '../screens/heat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';
import '../utils/map_focus.dart';
import '../widgets/reveal_scope.dart';
import 'app_bottom_nav.dart';

/// The main application shell: a persistent bottom navigation bar with five
/// destinations and an [IndexedStack] body so each screen keeps its state
/// when switching tabs.
///
/// The five tabs mirror the legacy web app's bottom nav:
/// Home, Heat Data, Map, Community, Profile. The Map tab is the raised
/// circular centerpiece of the bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    HeatScreen(),
    MapScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  /// Per-tab counters bumped whenever that tab becomes active. Screens stay
  /// alive inside the [IndexedStack], so this is what tells their cards to
  /// replay the entrance animation when the user returns to the tab.
  final List<int> _activations = List<int>.filled(_screens.length, 0);

  /// Per-tab stagger allocators, so cards revealed together on one tab are
  /// sequenced independently of the other tabs.
  final List<RevealStagger> _staggers = List<RevealStagger>.generate(
    _screens.length,
    (_) => RevealStagger(),
  );

  /// Switches to [index], replaying that tab's entrance animations.
  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _activations[index]++;
    });
  }

  static const List<AppNavDestination> _destinations = <AppNavDestination>[
    AppNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    AppNavDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Heat Data',
    ),
    AppNavDestination(
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      label: 'Map',
    ),
    AppNavDestination(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Community',
    ),
    AppNavDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Allow the community screens to switch to the Map tab (e.g. when a
    // post's tagged location is tapped).
    mapFocus.addListener(_onMapFocus);
  }

  @override
  void dispose() {
    mapFocus.removeListener(_onMapFocus);
    super.dispose();
  }

  void _onMapFocus() {
    if (!mounted) return;
    _select(mapFocus.selectedTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let each screen's content flow behind the nav bar. The bar's top
      // [AppBottomNav.circleLift] strip is transparent, so without this the
      // Scaffold would stop the body at the bar's top edge and expose a solid
      // band of the bar's background color above it. Screens add
      // [AppBottomNav.bottomInsetOf] to their scrollable's bottom padding so
      // their last item still clears the bar.
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          for (var i = 0; i < _screens.length; i++)
            RevealScope(
              activation: _activations[i],
              stagger: _staggers[i],
              child: _screens[i],
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        destinations: _destinations,
      ),
    );
  }
}
