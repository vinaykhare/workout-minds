import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/welcome_screen.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
          _SettingsTile(
            icon: Icons.dark_mode,
            title: l10n.themeTitle,
            value: profile.themeMode == 'system'
                ? l10n.themeSystem
                : (profile.themeMode == 'light'
                      ? l10n.themeLight
                      : l10n.themeDark),
            onTap: () => _showOptionsDialog(
              context,
              l10n.themeTitle,
              profile.themeMode,
              ['system', 'light', 'dark'],
              (val) => notifier.updateField('themeMode', val),
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
            icon: Icons.handyman_outlined,
            title: l10n.styleTitle,
            value: profile.preferredStyle,
            onTap: () => _showOptionsDialog(
              context,
              l10n.styleTitle,
              profile.preferredStyle,
              [
                'Full Gym',
                'Home (Dumbbells/Bands)',
                'Bodyweight Only',
                'Yoga & Flexibility',
              ],
              (val) => notifier.updateField('preferredStyle', val),
            ),
          ),
          // --- NEW: STRENGTH BASELINE ---
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 16.0),
            child: Text(
              l10n.settingsStrengthBaseline, // <--- Localized
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.arrow_upward,
            title: l10n.settingsMaxPushups, // <--- Localized
            value: '${profile.pushupCapacity}',
            onTap: () => _showSliderDialog(
              context,
              l10n.settingsMaxPushups, // <--- Localized
              profile.pushupCapacity.toDouble(),
              0,
              100,
              (val) => notifier.updateField('pushupCapacity', val.toInt()),
            ),
          ),
          _SettingsTile(
            icon: Icons.fitness_center,
            title: l10n.settingsMaxPullups, // <--- Localized
            value: '${profile.pullupCapacity}',
            onTap: () => _showSliderDialog(
              context,
              l10n.settingsMaxPullups, // <--- Localized
              profile.pullupCapacity.toDouble(),
              0,
              50,
              (val) => notifier.updateField('pullupCapacity', val.toInt()),
            ),
          ),
          _SettingsTile(
            icon: Icons.airline_seat_legroom_extra,
            title: l10n.settingsMaxSquats, // <--- Localized
            value: '${profile.squatCapacity}',
            onTap: () => _showSliderDialog(
              context,
              l10n.settingsMaxSquats, // <--- Localized
              profile.squatCapacity.toDouble(),
              0,
              200,
              (val) => notifier.updateField('squatCapacity', val.toInt()),
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

          // --- CLOUD SYNC ---
          // --- CLOUD SYNC (Hidden on Windows/Web) ---
          if (!kIsWeb && !Platform.isWindows) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                'Cloud Backup',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withAlpha(100),
              child: Column(
                children: [
                  // --- NEW AUTO-SYNC TOGGLE ---
                  SwitchListTile(
                    secondary: const Icon(Icons.sync, color: Colors.tealAccent),
                    title: const Text(
                      'Auto-Sync Workouts',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Silently backs up when you finish a workout.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: profile.isAutoSyncEnabled,
                    activeThumbColor: Colors.tealAccent,
                    onChanged: (value) async {
                      if (value == true) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        // Run the silent backup to ensure auth works
                        final profileJsonString = jsonEncode(
                          profile.copyWith(isAutoSyncEnabled: true).toJson(),
                        );
                        final success = await ref
                            .read(driveSyncProvider)
                            .backupToCloud(profileJsonString);

                        // FIX 1: Explicitly check context.mounted
                        if (!context.mounted) return;

                        Navigator.pop(context); // Close the loader

                        if (success) {
                          await ref
                              .read(userProfileProvider.notifier)
                              .updateField('isAutoSyncEnabled', true);

                          // FIX 2: Explicitly check context.mounted
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Auto-Sync Enabled!',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          );
                        } else {
                          // FIX 3: Explicitly check context.mounted
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not enable Auto-Sync. Auth failed.',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } else {
                        // Turning OFF
                        await ref
                            .read(userProfileProvider.notifier)
                            .updateField('isAutoSyncEnabled', false);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                    title: const Text(
                      'Backup to Google Drive',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      final profileJsonString = jsonEncode(profile.toJson());

                      showDialog(
                        context: context,
                        barrierDismissible: false, // Force them to wait!
                        builder: (context) => SyncProgressDialog(
                          isBackup: true,
                          profileJson: profileJsonString,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.cloud_download,
                      color: Colors.green,
                    ),
                    title: const Text(
                      'Restore from Cloud',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false, // Force them to wait!
                        builder: (context) =>
                            const SyncProgressDialog(isBackup: false),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever, // Changed to a trash can
                      color: Colors.redAccent, // Red for destructive actions
                    ),
                    title: const Text(
                      'Delete Cloud Backup',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently remove your data from Google Drive',
                    ),
                    onTap: () async {
                      // 1. Show Safety Confirmation Dialog First!
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 8),
                              Text('Delete Cloud Data?'),
                            ],
                          ),
                          content: const Text(
                            'This will permanently remove your workout history and profile from Google Drive. \n\nYour local data on this phone will NOT be affected.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete Backup'),
                            ),
                          ],
                        ),
                      );

                      // 2. If confirmed, execute the wipe
                      if (confirm == true && context.mounted) {
                        // Show a simple loading dialog so they know it's working
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            content: Row(
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Text('Deleting from Google Drive...'),
                                ),
                              ],
                            ),
                          ),
                        );

                        // Execute the wipe
                        final success = await ref
                            .read(driveSyncProvider)
                            .deleteCloudBackup();

                        // Close the loading dialog
                        if (context.mounted) Navigator.pop(context);

                        // Show the success/fail snackbar
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Cloud backup permanently deleted.'
                                    : 'Failed to delete backup.',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: success
                                  ? Colors.green
                                  : Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 24),

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
          // FIX: The new Flutter 3.32+ RadioGroup Wrapper!
          content: RadioGroup<String>(
            groupValue: tempValue,
            onChanged: (val) {
              if (val != null) {
                setState(() => tempValue = val);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (opt) => RadioListTile<String>(
                      title: Text(opt),
                      value: opt,
                      // Notice how groupValue and onChanged are completely gone from here!
                    ),
                  )
                  .toList(),
            ),
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
                      // Navigator.of(context).popUntil((route) => route.isFirst);
                      // FIX: Explicitly route to the Welcome Screen and destroy the back-history!
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const WelcomeScreen(),
                        ),
                        (route) => false,
                      );
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

// --- NEW SMART DIALOG ---
class SyncProgressDialog extends ConsumerStatefulWidget {
  final bool isBackup;
  final String? profileJson;

  const SyncProgressDialog({
    super.key,
    required this.isBackup,
    this.profileJson,
  });

  @override
  ConsumerState<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends ConsumerState<SyncProgressDialog> {
  String _status = 'Starting...';
  bool _isProcessing = true;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    final syncService = ref.read(driveSyncProvider);

    // Give UI a split second to render the dialog before locking the thread
    await Future.delayed(const Duration(milliseconds: 300));

    if (widget.isBackup) {
      // --- RUN BACKUP ---
      final success = await syncService.backupToCloud(
        widget.profileJson!,
        onStatus: (msg) {
          if (mounted) setState(() => _status = msg);
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = success;
          if (!success && _status == 'Starting...') _status = 'Backup Failed.';
        });
      }
    } else {
      // --- RUN RESTORE ---
      final restoredJson = await syncService.restoreFromCloud(
        onStatus: (msg) {
          if (mounted) setState(() => _status = msg);
        },
      );

      if (mounted) {
        if (restoredJson != null) {
          // Process the Riverpod state updates inside the dialog!
          final restoredProfile = UserProfile.fromJson(
            jsonDecode(restoredJson),
          );
          await ref
              .read(userProfileProvider.notifier)
              .saveProfile(restoredProfile);

          ref.invalidate(databaseProvider);
          ref.invalidate(weeklyStatsProvider);
          ref.invalidate(recentWorkoutsProvider);
          ref.invalidate(workoutsStreamProvider);

          setState(() {
            _isProcessing = false;
            _isSuccess = true;
            _status = 'Restore Complete!';
          });
        } else {
          setState(() {
            _isProcessing = false;
            _isSuccess = false;
            if (_status == 'Starting...') _status = 'Restore Failed.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isBackup ? 'Cloud Backup' : 'Cloud Restore'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessing)
            const LinearProgressIndicator()
          else if (_isSuccess)
            const Icon(Icons.check_circle, color: Colors.green, size: 64)
          else
            const Icon(Icons.error, color: Colors.redAccent, size: 64),

          const SizedBox(height: 24),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: _isProcessing ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        // The button is strictly hidden until processing finishes!
        if (!_isProcessing)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ),
      ],
    );
  }
}
