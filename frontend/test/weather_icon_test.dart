import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/widgets/weather_icon.dart';

const String _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
  <circle cx="50" cy="50" r="40" fill="orange"/>
</svg>
''';

/// A fake HTTP client that fails the first [failuresRemaining] requests with
/// a 500 and then returns the SVG.
class _FakeIconClient extends http.BaseClient {
  _FakeIconClient({this.failuresRemaining = 0});

  int failuresRemaining;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      return http.StreamedResponse(
        Stream<Uint8List>.value(
          Uint8List.fromList(utf8.encode('{"message":"database locked"}')),
        ),
        500,
      );
    }
    return http.StreamedResponse(
      Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(_svg))),
      200,
      headers: <String, String>{'content-type': 'image/svg+xml'},
    );
  }
}

void main() {
  testWidgets('renders the SVG when the icon loads successfully',
      (WidgetTester tester) async {
    final api = ApiClient(client: _FakeIconClient());
    await tester.pumpWidget(
      MaterialApp(
        home: WeatherIcon(iconBaseUri: 'https://maps.gstatic.com/weather/v1/sunny', api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.wb_cloudy_outlined), findsNothing);
  });

  testWidgets('shows the cloud placeholder when the icon fails',
      (WidgetTester tester) async {
    final api = ApiClient(client: _FakeIconClient(failuresRemaining: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: WeatherIcon(iconBaseUri: 'https://maps.gstatic.com/weather/v1/rainy', api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.wb_cloudy_outlined), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('retries a failed icon when retryToken changes',
      (WidgetTester tester) async {
    final client = _FakeIconClient(failuresRemaining: 1);
    final api = ApiClient(client: client);
    final harnessKey = GlobalKey<_RetryHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _RetryHarness(
          key: harnessKey,
          api: api,
          retryToken: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.wb_cloudy_outlined), findsOneWidget);

    // Backend recovers; bump the retry token to force a re-fetch.
    harnessKey.currentState!.bump();
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.wb_cloudy_outlined), findsNothing);
  });
}

/// Keeps a [WeatherIcon] at a stable position so that changing [retryToken]
/// triggers `didUpdateWidget` on the icon's state.
class _RetryHarness extends StatefulWidget {
  const _RetryHarness({super.key, required this.api, required this.retryToken});

  final ApiClient api;
  final int retryToken;

  @override
  State<_RetryHarness> createState() => _RetryHarnessState();
}

class _RetryHarnessState extends State<_RetryHarness> {
  late int _retryToken = widget.retryToken;

  void bump() {
    setState(() => _retryToken++);
  }

  @override
  Widget build(BuildContext context) {
    return WeatherIcon(
      iconBaseUri: 'https://maps.gstatic.com/weather/v1/stormy',
      api: widget.api,
      retryToken: _retryToken,
    );
  }
}
