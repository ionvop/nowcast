import 'package:flutter/material.dart';

import '../widgets/placeholder_view.dart';

/// Heat Data tab: a multi-series line chart of temperature, feels-like, dew
/// point, heat index, wind chill, and wet bulb. Currently a non-functional
/// placeholder.
class HeatScreen extends StatelessWidget {
  const HeatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heat Data'),
      ),
      body: const PlaceholderView(
        icon: Icons.bar_chart_outlined,
        title: 'Heat Data Chart',
        description: 'A chart comparing temperature, feels-like, dew point, '
            'heat index, wind chill, and wet bulb will appear here.',
      ),
    );
  }
}