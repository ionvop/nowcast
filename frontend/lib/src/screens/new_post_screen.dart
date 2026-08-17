import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../utils/geolocation.dart';
import '../widgets/loading_overlay.dart';

/// New Post composer: a content field with an optional "include my current
/// location" toggle. Submits the post to the API and pops with `true` on
/// success so the feed can refresh.
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _contentController = TextEditingController();
  bool _includeLocation = false;
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnack('Please write something before posting.');
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final token = authController.token;
      if (token == null) {
        _showSnack('You need to sign in to post.');
        return;
      }

      final body = <String, dynamic>{'content': content};

      if (_includeLocation) {
        final position = await getPosition(subject: 'your post');
        if (!mounted) return;
        body['latitude'] = position.latitude;
        body['longitude'] = position.longitude;

        // Reverse-geocode to a human-readable address.
        final geocodeJson = await _api.post('geocode', <String, dynamic>{
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
        final address = _addressFromGeocode(geocodeJson);
        if (address != null) {
          body['address'] = address;
        }
      }

      await _api.post('posts', body, token: token);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await authController.signOut();
        if (!mounted) return;
        _showSnack('Your session expired. Please sign in again.');
        return;
      }
      _showSnack(e.message);
    } on NetworkException catch (e) {
      _showSnack(e.message);
    } on Exception {
      _showSnack('Something went wrong while posting. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _addressFromGeocode(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is Map<String, dynamic> && first['formattedAddress'] is String) {
      return first['formattedAddress'] as String;
    }
    return null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            controller: _contentController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText:
                                  'What are the conditions like where you are?',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _includeLocation,
                            onChanged: _submitting
                                ? null
                                : (value) {
                                    setState(() {
                                      _includeLocation = value;
                                    });
                                  },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Include my current location'),
                            subtitle: _includeLocation
                                ? const Text(
                                    'Your location will be shown on this post.')
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.seed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
          ),
          if (_submitting)
            const Positioned.fill(
              child: LoadingOverlay(label: 'Posting…'),
            ),
        ],
      ),
    );
  }
}