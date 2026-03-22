import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Color _getBMIColor(double bmi) {
    if (bmi == 0) return Colors.grey;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return Colors.redAccent;
  }

  String _getBMICategory(double bmi) {
    if (bmi == 0) return 'Unknown';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal Weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    final bmiColor = _getBMIColor(profile.bmi);

    // Map the locale code to a readable string
    final displayLanguage = profile.appLocale == 'hi' ? 'Hinglish' : 'English';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- 1. BMI & METRICS CARD ---
          Card(
            elevation: 0,
            color: bmiColor.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: bmiColor.withAlpha(100), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Current BMI',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.bmi > 0 ? profile.bmi.toStringAsFixed(1) : '--',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: bmiColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bmiColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getBMICategory(profile.bmi),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- 2. APP PREFERENCES ---
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'App Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.language,
            title: 'App Language',
            value: displayLanguage,
            onTap: () => _showOptionsDialog(
              context,
              'App Language',
              displayLanguage,
              ['English', 'Hinglish'],
              (val) {
                // Map the readable string back to the locale code
                final localeCode = val == 'Hinglish' ? 'hi' : 'en';
                notifier.updateField('appLocale', localeCode);
              },
            ),
          ),

          const SizedBox(height: 24),

          // --- 3. EDITABLE PROFILE METRICS ---
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Body Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.height,
            title: 'Height',
            value: '${profile.heightCm.toInt()} cm',
            onTap: () => _showSliderDialog(
              context,
              'Height (cm)',
              profile.heightCm,
              120,
              220,
              (val) => notifier.updateField('heightCm', val),
            ),
          ),
          _SettingsTile(
            icon: Icons.monitor_weight_outlined,
            title: 'Weight',
            value: '${profile.weightKg.toInt()} kg',
            onTap: () => _showSliderDialog(
              context,
              'Weight (kg)',
              profile.weightKg,
              40,
              150,
              (val) => notifier.updateField('weightKg', val),
            ),
          ),

          const SizedBox(height: 24),

          // --- 4. FITNESS GOALS ---
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Fitness Journey',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.flag_outlined,
            title: 'Primary Goal',
            value: profile.goal,
            onTap: () => _showOptionsDialog(
              context,
              'Primary Goal',
              profile.goal,
              ['Lose Weight', 'Build Muscle', 'Stay Fit'],
              (val) => notifier.updateField('goal', val),
            ),
          ),
          _SettingsTile(
            icon: Icons.fitness_center,
            title: 'Experience Level',
            value: profile.experienceLevel,
            onTap: () => _showOptionsDialog(
              context,
              'Experience',
              profile.experienceLevel,
              ['Beginner', 'Intermediate', 'Advanced'],
              (val) => notifier.updateField('experienceLevel', val),
            ),
          ),

          const SizedBox(height: 48),

          // --- 5. DANGER ZONE ---
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
          Card(
            color: Colors.redAccent.withAlpha(20),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.redAccent.withAlpha(100)),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Erase All Data & Restart',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Wipes all workout history and resets app.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () => _showWipeDataDialog(context, ref),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- REUSABLE DIALOG HELPERS ---

  void _showSliderDialog(
    BuildContext context,
    String title,
    double currentValue,
    double min,
    double max,
    Function(double) onSave,
  ) {
    double tempValue = currentValue;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Update $title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tempValue.toInt().toString(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: tempValue,
                min: min,
                max: max,
                onChanged: (val) => setState(() => tempValue = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(tempValue);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsDialog(
    BuildContext context,
    String title,
    String currentValue,
    List<String> options,
    Function(String) onSave,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update $title'),
        content: RadioGroup<String>(
          groupValue: currentValue,
          onChanged: (val) {
            if (val != null) {
              onSave(val);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (opt) => RadioListTile<String>(title: Text(opt), value: opt),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showWipeDataDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'Factory Reset',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete all your workout logs, custom routines, and settings. This cannot be undone.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Type "DELETE" to confirm:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'DELETE',
                ),
                onChanged: (val) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: textController.text == 'DELETE'
                  ? () async {
                      await ref.read(databaseProvider).wipeAllUserData();
                      final prefs = ref.read(sharedPreferencesProvider);
                      await prefs.clear();
                      await ref
                          .read(userProfileProvider.notifier)
                          .updateField('hasOnboarded', false);

                      if (!context.mounted) return;

                      // Properly pop away the dialog and settings screen to reveal Onboarding
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  : null,
              child: const Text('ERASE EVERYTHING'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withAlpha(100),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
