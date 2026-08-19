import 'package:flutter/material.dart';

import '../screens/community_screen.dart';
import '../screens/heat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';
import '../utils/map_focus.dart';

/// The main application shell: a persistent bottom navigation bar with five
/// destinations and an [IndexedStack] body so each screen keeps its state
/// when switching tabs.
///
/// The five tabs mirror the legacy web app's bottom nav:
/// Home, Heat Data, Map, Community, Profile.
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
    setState(() {
      _selectedIndex = mapFocus.selectedTab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Heat Data',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
