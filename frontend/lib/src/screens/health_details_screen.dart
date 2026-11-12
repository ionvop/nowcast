import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_profile.dart';
import '../services/health_profile_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/fade_slide_in.dart';

/// Form for entering and updating the personal and health details that drive
/// the heat-risk assessment.
///
/// Only age and biological sex are required; every other field is optional so
/// the user can share as much or as little as they are comfortable with. Pops
/// `true` when the profile was saved or cleared so the caller can refresh.
class HealthDetailsScreen extends StatefulWidget {
  const HealthDetailsScreen({super.key, this.controller});

  /// Injectable controller for tests. Defaults to the app-wide singleton.
  final HealthProfileController? controller;

  @override
  State<HealthDetailsScreen> createState() => _HealthDetailsScreenState();
}

class _HealthDetailsScreenState extends State<HealthDetailsScreen> {
  late final HealthProfileController _controller =
      widget.controller ?? healthProfileController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String? _sex;
  String? _activityLevel;
  final Set<String> _conditions = <String>{};
  final Set<String> _medications = <String>{};
  final Set<String> _lifestyle = <String>{};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrate(_controller.profile);
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Fills the form from [profile], if there is one.
  void _hydrate(HealthProfile? profile) {
    if (profile == null) return;
    _ageController.text = profile.age?.toString() ?? '';
    _heightController.text = _trimZero(profile.heightCm);
    _weightController.text = _trimZero(profile.weightKg);
    _sex = profile.biologicalSex;
    _activityLevel = profile.activityLevel;
    _conditions
      ..clear()
      ..addAll(profile.conditions);
    _medications
      ..clear()
      ..addAll(profile.medications);
    _lifestyle
      ..clear()
      ..addAll(profile.lifestyle);
  }

  /// Renders `162.5` as `162.5` and `162.0` as `162`.
  static String _trimZero(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_sex == null) {
      _showSnack('Select a biological sex to continue.');
      return;
    }

    setState(() => _saving = true);

    final profile = HealthProfile(
      age: int.tryParse(_ageController.text.trim()),
      biologicalSex: _sex,
      heightCm: double.tryParse(_heightController.text.trim()),
      weightKg: double.tryParse(_weightController.text.trim()),
      activityLevel: _activityLevel,
      conditions: _conditions.toList(growable: false),
      medications: _medications.toList(growable: false),
      lifestyle: _lifestyle.toList(growable: false),
    );

    final ok = await _controller.save(profile);
    if (!mounted) return;

    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    _showSnack(_controller.error ?? 'Could not save your health details.');
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear health details?'),
        content: const Text(
          'This deletes your saved health details. Your generated assessment '
          'stays on the Heat Data page until you clear it there.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final ok = await _controller.clear();
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    _showSnack(_controller.error ?? 'Could not clear your health details.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = _controller.profile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health details'),
        actions: <Widget>[
          if (hasProfile)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear health details',
              onPressed: _saving ? null : _clear,
            ),
        ],
      ),
      // This is a pushed route, not a shell tab, so nothing above it reserves
      // the system navigation bar inset — the SafeArea does it here.
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: <Widget>[
              Text(
                'These details personalize your heat-risk assessment. Only age '
                'and biological sex are required.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(child: _aboutYouCard()),
              FadeSlideIn(child: _conditionsCard()),
              FadeSlideIn(child: _medicationsCard()),
              FadeSlideIn(child: _lifestyleCard()),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save details'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutYouCard() {
    return _SectionCard(
      icon: Icons.person_outline,
      title: 'About you',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Age',
              suffixText: 'years',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final age = int.tryParse((value ?? '').trim());
              if (age == null) return 'Enter your age.';
              if (age < 1 || age > 120) return 'Enter an age between 1 and 120.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Biological sex',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: kHealthSexes
                .map(
                  (sex) => ButtonSegment<String>(
                    value: sex,
                    label: Text(kHealthSexLabels[sex] ?? sex),
                  ),
                )
                .toList(growable: false),
            selected: <String>{?_sex},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) {
              setState(() => _sex = selection.isEmpty ? null : selection.first);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    suffixText: 'cm',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _validateOptionalRange(
                    value,
                    min: 50,
                    max: 250,
                    label: 'height',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _validateOptionalRange(
                    value,
                    min: 20,
                    max: 300,
                    label: 'weight',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _activityLevel,
            decoration: const InputDecoration(
              labelText: 'Activity level',
              border: OutlineInputBorder(),
            ),
            items: kActivityLevels
                .map(
                  (level) => DropdownMenuItem<String>(
                    value: level,
                    child: Text(kActivityLevelLabels[level] ?? level),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _activityLevel = value),
          ),
        ],
      ),
    );
  }

  /// Validates an optional numeric field, allowing it to be left blank.
  static String? _validateOptionalRange(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null) return 'Enter a number.';
    if (number < min || number > max) {
      return 'Enter a $label between ${min.toInt()} and ${max.toInt()}.';
    }
    return null;
  }

  Widget _conditionsCard() {
    return _SectionCard(
      icon: Icons.favorite_border,
      title: 'Health conditions',
      subtitle: 'Optional — select any that apply.',
      child: _chipWrap(
        options: kHealthConditions,
        labels: kHealthConditionLabels,
        selected: _conditions,
      ),
    );
  }

  Widget _medicationsCard() {
    return _SectionCard(
      icon: Icons.medication_outlined,
      title: 'Medications',
      subtitle: 'Optional — select any you take regularly.',
      child: _chipWrap(
        options: kHealthMedications,
        labels: kHealthMedicationLabels,
        selected: _medications,
      ),
    );
  }

  Widget _lifestyleCard() {
    return _SectionCard(
      icon: Icons.directions_run,
      title: 'Lifestyle',
      subtitle: 'Optional — select any that apply.',
      child: _chipWrap(
        options: kHealthLifestyle,
        labels: kHealthLifestyleLabels,
        selected: _lifestyle,
      ),
    );
  }

  Widget _chipWrap({
    required List<String> options,
    required Map<String, String> labels,
    required Set<String> selected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(labels[option] ?? option),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                selected.add(option);
              } else {
                selected.remove(option);
              }
            });
          },
        );
      }).toList(growable: false),
    );
  }
}

/// A titled card used for each group of form fields.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: AppTheme.seed),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
