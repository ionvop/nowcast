import 'package:flutter/material.dart';

import '../widgets/placeholder_view.dart';

/// Home tab: current weather condition, icon, temperature, and an hourly
/// forecast strip. Currently a non-functional placeholder.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowcast'),
      ),
      body: const PlaceholderView(
        icon: Icons.wb_sunny_outlined,
        title: 'Current Weather',
        description: 'Your current weather condition, temperature, and hourly '
            'forecast will appear here once location and weather services are '
            'connected.',
      ),
    );
  }
}