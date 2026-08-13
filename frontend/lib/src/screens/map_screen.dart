import 'package:flutter/material.dart';

import '../widgets/placeholder_view.dart';

/// Map tab: an interactive map with colored heat markers that can be
/// tapped to analyze a location's heat index. Currently a non-functional
/// placeholder.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heat Map'),
      ),
      body: const PlaceholderView(
        icon: Icons.map_outlined,
        title: 'Community Heat Map',
        description: 'An interactive map of crowd-sourced heat readings will '
            'appear here. Tap a location to analyze its heat index.',
      ),
    );
  }
}