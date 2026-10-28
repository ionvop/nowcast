// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:nowcast/main.dart';

/// A fake geolocator platform so the tab screens' `getPosition()` calls resolve
/// immediately instead of leaving the 15s location timeout timer pending at
/// teardown.
class FakeGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    return Future<Position>.value(
      Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ),
    );
  }
}

void main() {
  setUp(() {
    GeolocatorPlatform.instance = FakeGeolocator();
  });

  testWidgets('App shell renders with five navigation destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NowcastApp());
    // Let the tab screens' initial loads finish so no timers are left pending.
    // (pumpAndSettle cannot be used: the loading spinner animates forever.)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The root app should be present.
    expect(find.byType(NowcastApp), findsOneWidget);

    // The five bottom navigation destinations should be shown.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Heat Data'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('App shell lets content flow behind the bottom nav',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NowcastApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The shell's Scaffold is the outermost one; the tab screens nest their
    // own Scaffolds inside it.
    final shell = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(shell.extendBody, isTrue);
  });
}
