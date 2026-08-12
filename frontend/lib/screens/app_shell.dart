import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pwa_install_service.dart';

/// Bottom navigation container for the 5 tabs.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.tabs,
    required this.titles,
  });

  final List<Widget> tabs;
  final List<String> titles;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person),
            onPressed: () => setState(() => _index = 4),
          ),
        ],
      ),
      body: Column(
        children: [
          const _InstallBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: widget.tabs),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Heat Data',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
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

/// Shows a dismissible "Install Nowcast" banner on web when install is
/// available. Hidden on native.
class _InstallBanner extends StatelessWidget {
  const _InstallBanner();

  @override
  Widget build(BuildContext context) {
    final pwa = context.watch<PwaInstallService>();
    if (!pwa.installAvailable) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF00AAFF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.download, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Install Nowcast for offline access',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => pwa.promptInstall(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white24,
              ),
              child: const Text('Install'),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => pwa.dismissInstallBanner(),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}