import 'package:flutter/material.dart';

/// Privacy Policy page: a static, in-app explanation of how Nowcast collects,
/// uses, stores, and protects user data.
///
/// The content is grounded in the actual implementation: the backend
/// (`../backend/`) is a Laravel JSON API that authenticates exclusively via
/// Google OAuth, stores only the name/email/avatar returned by Google, keeps
/// anonymous weather readings for one hour, and expires community posts after
/// 24 hours. No analytics or advertising are used.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _section(
            context,
            'Introduction',
            'Nowcast is a weather and heat-health monitoring app. It shows '
            'current conditions and forecasts, warns about heat danger, and '
            'lets you share weather observations with the community. This '
            'policy explains what information we collect, how we use it, and '
            'the choices you have.',
          ),
          _section(
            context,
            'Information We Collect',
            'Account information. You sign in with your Google account. We '
            'receive your name, email address, and profile picture from '
            'Google. We never store a password, because you do not create '
            'one with us.\n\n'
            'Location data. To show weather and heat information for your '
            'area, the app reads your device location and sends the '
            'coordinates to our server with each request. These readings are '
            'stored anonymously, are not linked to your account, and are '
            'automatically removed after one hour. When you post to the '
            'community, your location and a nearby address are included only '
            'if you choose to attach them.\n\n'
            'Community posts. Anything you write in the community feed is '
            'stored with your public profile name and avatar.\n\n'
            'Device data. Your preferences (such as dark mode, 24-hour time, '
            'and vibration) and notifications are stored locally on your '
            'device and are not uploaded.',
          ),
          _section(
            context,
            'How We Use Your Information',
            'We use the information we collect to provide the app\u2019s core '
            'features: current weather and forecasts, heat-danger alerts, '
            'reverse geocoding of your location, and the community feed. '
            'Aggregate, anonymous weather readings help keep the service '
            'accurate for everyone. We do not use your data for advertising '
            'or sell it to third parties.',
          ),
          _section(
            context,
            'Third-Party Services',
            'Weather, geocoding, and sign-in data are provided by Google. '
            'Your device location is read using your device\u2019s location '
            'services, and the interactive map is rendered by Google Maps on '
            'your device. These services have their own privacy policies, '
            'which we encourage you to review.',
          ),
          _section(
            context,
            'Data Retention',
            'Anonymous weather readings are removed after one hour. Community '
            'posts expire and are deleted after 24 hours. Your sign-in token '
            'remains valid until you sign out, at which point it is revoked.',
          ),
          _section(
            context,
            'Your Choices and Control',
            'You can sign out at any time, which revokes your sign-in token. '
            'You can delete your own community posts. You can deny or '
            'withdraw location permission from your device settings. '
            'Currently there is no way to delete your account from within '
            'the app; if you would like your account and data removed, '
            'please contact us using the details below.',
          ),
          _section(
            context,
            'Security',
            'We do not store passwords. Google API keys are kept only on our '
            'server and are never exposed to the app. Requests are validated '
            'and rate-limited to help protect the service. Your sign-in '
            'token is stored securely on your device.',
          ),
          _section(
            context,
            'Analytics and Cookies',
            'We do not use analytics, tracking pixels, or advertising. The '
            'app uses a token-based API rather than browser cookies, and we '
            'do not sell or share your personal information.',
          ),
          _section(
            context,
            'Contact Us',
            'If you have questions about this policy or your data, please '
            'contact us at privacy@nowcast.app.',
          ),
          _section(
            context,
            'Changes to This Policy',
            'We may update this policy from time to time. When we do, the '
            'latest version will always be available here in the app.',
          ),
        ],
      ),
    );
  }

  /// Builds a titled content section as a themed card, matching the padding
  /// and text styles used elsewhere in the app.
  Widget _section(BuildContext context, String title, String body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}