import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../overlay/activities_bubble_controller.dart';
import 'ai_sign_in_prompt.dart';
import 'ai_summary_section.dart';
import 'bubble_toggle_card.dart';

/// The Home tab's AI block: the AI summary card plus, on Android, the toggle
/// for the floating AI activities bubble.
///
/// Both features are gated to signed-in users. When no token is stored the
/// block collapses to a single sign-in prompt so the Home page never offers an
/// AI action that would fail.
class AiFeaturesSection extends StatelessWidget {
  const AiFeaturesSection({
    super.key,
    required this.currentConditions,
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.hourlyForecast,
    this.dailyForecast,
    this.api,
    this.auth,
    this.bubbleController,
  });

  /// The raw Google current-conditions payload (see API §5.1).
  final Map<String, dynamic> currentConditions;

  /// The device latitude the weather payloads were fetched for.
  final double latitude;

  /// The device longitude the weather payloads were fetched for.
  final double longitude;

  /// A human-readable place name (e.g. the reverse-geocoded city). Optional.
  final String? placeName;

  /// The raw Google hourly forecast payload (see API §5.2). Optional.
  final Map<String, dynamic>? hourlyForecast;

  /// The raw Google daily forecast payload (see API §5.3). Optional.
  final Map<String, dynamic>? dailyForecast;

  /// Injectable client for tests, forwarded to [AiSummarySection].
  final ApiClient? api;

  /// Injectable auth state for tests. Defaults to the app-wide singleton.
  final AuthController? auth;

  /// Injectable bubble controller for tests. Defaults to the app-wide
  /// singleton.
  final ActivitiesBubbleController? bubbleController;

  @override
  Widget build(BuildContext context) {
    final auth = this.auth ?? authController;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.isAuthenticated) {
          return AiSignInPrompt(auth: auth);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AiSummarySection(
              currentConditions: currentConditions,
              latitude: latitude,
              longitude: longitude,
              placeName: placeName,
              hourlyForecast: hourlyForecast,
              dailyForecast: dailyForecast,
              api: api,
            ),
            // The overlay window plugin is Android-only.
            if (defaultTargetPlatform == TargetPlatform.android) ...<Widget>[
              const SizedBox(height: 16),
              BubbleToggleCard(controller: bubbleController),
            ],
          ],
        );
      },
    );
  }
}


