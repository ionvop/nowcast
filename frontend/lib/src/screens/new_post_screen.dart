import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// New Post composer: a content field with an optional "include my current
/// location" toggle. Currently a non-functional placeholder.
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _includeLocation = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
      ),
      body: SafeArea(
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
                          hintText: 'What are the conditions like where you are?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _includeLocation,
                        onChanged: (value) {
                          setState(() {
                            _includeLocation = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include my current location'),
                        subtitle: _includeLocation
                            ? const Text('Your location will be shown on this post.')
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  // TODO: submit the post once the API is wired up.
                },
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
    );
  }
}