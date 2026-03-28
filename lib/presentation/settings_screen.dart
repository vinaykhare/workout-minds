import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';

// CHANGED: Converted to ConsumerStatefulWidget to manage the text field and dropdown
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;

  // A predefined list of supported models
  final List<String> _availableModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  String _selectedModel = 'gemini-2.5-flash-lite';

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _apiKeyController = TextEditingController(text: profile.customApiKey);

    if (profile.customModelName.isNotEmpty &&
        _availableModels.contains(profile.customModelName)) {
      _selectedModel = profile.customModelName;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

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

  // Helper to save profile safely with the new fields
  Future<void> _saveProSettings(
    UserProfile currentProfile, {
    bool? isPro,
    String? apiKey,
    String? modelName,
  }) async {
    final updatedProfile = currentProfile.copyWith(
      isPro: isPro ?? currentProfile.isPro,
      customApiKey: apiKey ?? currentProfile.customApiKey,
      customModelName: modelName ?? currentProfile.customModelName,
    );
    await ref.read(userProfileProvider.notifier).saveProfile(updatedProfile);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    final bmiColor = _getBMIColor(profile.bmi);
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
          const SizedBox(height: 24),

          // --- 5. SUBSCRIPTION & AI SETTINGS ---
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Subscription & AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.star,
            title: 'AI Credits Remaining',
            value: profile.isPro ? 'Unlimited' : '${profile.aiCredits}',
            onTap: () {
              // Dev test: Give 5 credits
              notifier.updateField('aiCredits', profile.aiCredits + 5);
            },
          ),
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withAlpha(100),
            child: SwitchListTile(
              secondary: const Icon(
                Icons.workspace_premium,
                color: Colors.deepPurpleAccent,
              ),
              title: const Text(
                'Enable Pro Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Unlock BYOK (Bring Your Own Key)',
                style: TextStyle(fontSize: 12),
              ),
              value: profile.isPro,
              activeThumbColor: Colors.deepPurpleAccent,
              onChanged: (value) => _saveProSettings(profile, isPro: value),
            ),
          ),

          // --- Power User (BYOK) Section (Only visible if Pro) ---
          if (profile.isPro) ...[
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.deepPurpleAccent.withAlpha(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.deepPurpleAccent.withAlpha(50)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.key,
                          size: 16,
                          color: Colors.deepPurpleAccent,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'POWER USER CONFIG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurpleAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Custom Gemini API Key',
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.save,
                            color: Colors.deepPurpleAccent,
                          ),
                          onPressed: () {
                            _saveProSettings(
                              profile,
                              apiKey: _apiKeyController.text.trim(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('API Key Saved!')),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedModel,
                      decoration: InputDecoration(
                        labelText: 'Preferred AI Model',
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: _availableModels.map((String model) {
                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(model),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedModel = newValue);
                          _saveProSettings(profile, modelName: newValue);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 48),

          // --- 6. DANGER ZONE ---
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
    String tempValue = currentValue; // Track the local state
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Update $title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (opt) => RadioListTile<String>(title: Text(opt), value: opt),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(tempValue); // Save to Riverpod
                Navigator.pop(context); // Close dialog
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
                      // 1. Wipe the Database
                      await ref.read(databaseProvider).wipeAllUserData();

                      // 2. Wipe Preferences
                      // (Ensure you have sharedPreferencesProvider defined,
                      // or use SharedPreferences.getInstance() directly here)
                      // final prefs = ref.read(sharedPreferencesProvider);
                      // await prefs.clear();

                      // 3. Reset User Profile to trigger onboarding
                      await ref
                          .read(userProfileProvider.notifier)
                          .updateField('hasOnboarded', false);

                      // 4. FIX: Force the Dashboard graph to redraw its empty state!
                      ref.invalidate(weeklyStatsProvider);
                      // ref.invalidate(workoutsStreamProvider); // Add this if needed

                      if (!context.mounted) return;
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
