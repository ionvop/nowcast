import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/location_service.dart';
import '../state/app_state.dart';
import '../widgets/alert_dialog.dart';

/// New Post screen: text area, optional current-location, submit.
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _controller = TextEditingController();
  final _locationService = const LocationService();

  bool _includeLocation = false;
  bool _submitting = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    // Reset the form each time the page opens.
    _controller.clear();
    _includeLocation = false;
    _enabled = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    final api = app.api;

    final content = _controller.text.trim();
    if (content.isEmpty) {
      await showAppAlert(context, message: 'Please enter some content.');
      return;
    }

    setState(() {
      _submitting = true;
      _enabled = false;
    });

    String? address;
    double? lat;
    double? lng;

    if (_includeLocation) {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (loc.denied) {
        setState(() {
          _submitting = false;
          _enabled = true;
        });
        await showAppAlert(
          context,
          message: 'Could not get your location. Please grant location '
              'permission or uncheck "Include my current location".',
        );
        return;
      }
      lat = loc.lat;
      lng = loc.lng;
      try {
        final geoJson = await api.post('/geocode', data: {
          'latitude': lat,
          'longitude': lng,
        });
        if (mounted) {
          final map = geoJson is Map
              ? Map<String, dynamic>.from(geoJson)
              : <String, dynamic>{};
          final results = map['results'];
          if (results is List && results.isNotEmpty) {
            final first = results.first;
            if (first is Map) {
              final formatted = first['formatted_address'];
              if (formatted is String) address = formatted;
            }
          }
        }
      } catch (_) {
        // Geocode failure is non-fatal; post without address.
      }
    }

    try {
      await api.post('/posts', data: {
        'content': content,
        'address': address,
        'latitude': lat,
        'longitude': lng,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiAuthException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _enabled = true;
      });
      await showAppAlert(
        context,
        message: 'You need to sign in to create a post.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _enabled = true;
      });
      await showAppAlert(context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _enabled = true;
      });
      await showAppAlert(
        context,
        message: 'Could not create the post. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              enabled: _enabled,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00AAFF)),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Include my current location'),
                Switch(
                  value: _includeLocation,
                  onChanged: _enabled
                      ? (v) => setState(() => _includeLocation = v)
                      : null,
                  activeTrackColor: const Color(0xFF00AAFF),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}