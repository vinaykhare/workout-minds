// lib/presentation/settings_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/welcome_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool scrollToBYOK;
  const SettingsScreen({super.key, this.scrollToBYOK = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  bool _isDriveConnected = false;
  String _userEmail = '';
  final GlobalKey _byokKey = GlobalKey();

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
    _checkDriveConnection();
    final profile = ref.read(userProfileProvider);
    _apiKeyController = TextEditingController(text: profile.customApiKey);

    if (profile.customModelName.isNotEmpty &&
        _availableModels.contains(profile.customModelName)) {
      _selectedModel = profile.customModelName;
    }

    // <-- NEW: Auto-scroll if instructed by AIGuard
    if (widget.scrollToBYOK) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_byokKey.currentContext != null) {
          Scrollable.ensureVisible(
            _byokKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _checkDriveConnection() async {
    final syncService = ref.read(driveSyncProvider);
    final connected = syncService.isSignedIn;
    if (mounted) {
      setState(() {
        _isDriveConnected = connected;
        _userEmail = syncService.currentUserEmail ?? 'Sync active';
      });
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

  String _getBMICategory(double bmi, AppLocalizations l10n) {
    if (bmi == 0) return l10n.bmiUnknown;
    if (bmi < 18.5) return l10n.bmiUnderweight;
    if (bmi < 25.0) return l10n.bmiNormal;
    if (bmi < 30.0) return l10n.bmiOverweight;
    return l10n.bmiObese;
  }

  Future<void> _saveAiSettings(
    UserProfile currentProfile, {
    String? apiKey,
    String? modelName,
  }) async {
    final updatedProfile = currentProfile.copyWith(
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

    ref.listen<UserProfile>(userProfileProvider, (previous, next) {
      if (previous != null &&
          previous.isAutoSyncEnabled &&
          next.isAutoSyncEnabled) {
        final profileJsonString = jsonEncode(next.toJson());
        ref.read(driveSyncProvider).backupToCloud(profileJsonString).ignore();
      }
    });

    final Map<String, String> langOptions = {
      'en': l10n.langEnglish,
      'hi': l10n.langHinglish,
    };
    final Map<String, String> themeOptions = {
      'system': l10n.themeSystem,
      'light': l10n.themeLight,
      'dark': l10n.themeDark,
    };
    final Map<String, String> goalOptions = {
      'Lose Weight': l10n.goalWeight,
      'Build Muscle': l10n.goalMuscle,
      'Stay Fit': l10n.goalFit,
    };
    final Map<String, String> styleOptions = {
      'Full Gym': l10n.styleGym,
      'Home (Dumbbells/Bands)': l10n.styleDumbbell,
      'Bodyweight Only': l10n.styleBodyweight,
      'Yoga & Flexibility': l10n.styleYoga,
    };

    final displayLanguage = langOptions[profile.appLocale] ?? l10n.langEnglish;

    // --- LEFT COLUMN WIDGETS ---
    final List<Widget> leftColumnWidgets = [
      Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Text(
          l10n.account,
          style: const TextStyle(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // <-- FIX: Replaced ListTile with Padding+Column to stop text overflow
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isDriveConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isDriveConnected ? l10n.signedInAs : l10n.signIn,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isDriveConnected ? _userEmail : l10n.signInDesc,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: _isDriveConnected
                    ? OutlinedButton(
                        onPressed: () async {
                          await ref.read(driveSyncProvider).signOut();
                          if (!context.mounted) return;
                          setState(() => _isDriveConnected = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.loggedOut)),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                        child: Text(l10n.logOut),
                      )
                    : FilledButton(
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          final success = await ref
                              .read(driveSyncProvider)
                              .signIn();
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (!success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.signInFailed),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            } else {
                              final mail =
                                  ref
                                      .read(driveSyncProvider)
                                      .currentUserEmail ??
                                  'Sync active';
                              setState(() {
                                _isDriveConnected = true;
                                _userEmail = mail;
                              });
                            }
                          }
                        },
                        child: Text(l10n.signIn),
                      ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
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
              Text(
                l10n.currentBmi,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                  _getBMICategory(profile.bmi, l10n),
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
      Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Text(
          l10n.appPreferences,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
      _SettingsTile(
        icon: Icons.language,
        title: l10n.appLanguage,
        value: displayLanguage,
        onTap: () => _showOptionsDialog(
          context,
          l10n.appLanguage,
          profile.appLocale,
          langOptions,
          (val) => notifier.updateField('appLocale', val),
          l10n,
        ),
      ),
      _SettingsTile(
        icon: Icons.dark_mode,
        title: l10n.themeTitle,
        value: themeOptions[profile.themeMode] ?? l10n.themeSystem,
        onTap: () => _showOptionsDialog(
          context,
          l10n.themeTitle,
          profile.themeMode,
          themeOptions,
          (val) => notifier.updateField('themeMode', val),
          l10n,
        ),
      ),
    ];

    // --- RIGHT COLUMN WIDGETS ---
    final List<Widget> rightColumnWidgets = [
      Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Text(
          l10n.bodyMetrics,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
      _SettingsTile(
        icon: Icons.height,
        title: l10n.heightLabel,
        value: '${profile.heightCm.toInt()} cm',
        onTap: () => _showSliderDialog(
          context,
          l10n.heightLabel,
          profile.heightCm,
          120,
          220,
          (val) => notifier.updateField('heightCm', val),
          l10n,
        ),
      ),
      _SettingsTile(
        icon: Icons.monitor_weight_outlined,
        title: l10n.weightLabel,
        value: '${profile.weightKg.toInt()} kg',
        onTap: () => _showSliderDialog(
          context,
          l10n.weightLabel,
          profile.weightKg,
          40,
          150,
          (val) => notifier.updateField('weightKg', val),
          l10n,
        ),
      ),
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Text(
          l10n.fitnessJourney,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
      _SettingsTile(
        icon: Icons.flag_outlined,
        title: l10n.goalTitle,
        value: goalOptions[profile.goal] ?? profile.goal,
        onTap: () => _showOptionsDialog(
          context,
          l10n.goalTitle,
          profile.goal,
          goalOptions,
          (val) => notifier.updateField('goal', val),
          l10n,
        ),
      ),
      _SettingsTile(
        icon: Icons.handyman_outlined,
        title: l10n.styleTitle,
        value: styleOptions[profile.preferredStyle] ?? profile.preferredStyle,
        onTap: () => _showOptionsDialog(
          context,
          l10n.styleTitle,
          profile.preferredStyle,
          styleOptions,
          (val) => notifier.updateField('preferredStyle', val),
          l10n,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 16.0),
        child: Text(
          l10n.settingsStrengthBaseline,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
      _SettingsTile(
        icon: Icons.arrow_upward,
        title: l10n.settingsMaxPushups,
        value: '${profile.pushupCapacity}',
        onTap: () => _showSliderDialog(
          context,
          l10n.settingsMaxPushups,
          profile.pushupCapacity.toDouble(),
          0,
          100,
          (val) => notifier.updateField('pushupCapacity', val.toInt()),
          l10n,
        ),
      ),
      _SettingsTile(
        icon: Icons.fitness_center,
        title: l10n.settingsMaxPullups,
        value: '${profile.pullupCapacity}',
        onTap: () => _showSliderDialog(
          context,
          l10n.settingsMaxPullups,
          profile.pullupCapacity.toDouble(),
          0,
          50,
          (val) => notifier.updateField('pullupCapacity', val.toInt()),
          l10n,
        ),
      ),
      _SettingsTile(
        icon: Icons.airline_seat_legroom_extra,
        title: l10n.settingsMaxSquats,
        value: '${profile.squatCapacity}',
        onTap: () => _showSliderDialog(
          context,
          l10n.settingsMaxSquats,
          profile.squatCapacity.toDouble(),
          0,
          200,
          (val) => notifier.updateField('squatCapacity', val.toInt()),
          l10n,
        ),
      ),
      const SizedBox(height: 24),

      // --- AI BYOK CONFIGURATION ---
      Padding(
        key: _byokKey, // <-- NEW: Attach the GlobalKey here
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Text(
          l10n.aiConfigTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
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
              Row(
                children: [
                  const Icon(
                    Icons.smart_toy,
                    size: 16,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.geminiAPICreds,
                    style: const TextStyle(
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
                  labelText: l10n.customGeminiKey,
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.save,
                      color: Colors.deepPurpleAccent,
                    ),
                    onPressed: () {
                      _saveAiSettings(
                        profile,
                        apiKey: _apiKeyController.text.trim(),
                      );
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l10n.apiKeySaved)));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedModel,
                decoration: InputDecoration(
                  labelText: l10n.preferredAiModel,
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
                    _saveAiSettings(profile, modelName: newValue);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.apiKeyDisclaimer,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),

      // --- CLOUD SYNC & DANGER ZONE ---
      if (!kIsWeb && !Platform.isWindows && _isDriveConnected) ...[
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            l10n.cloudBackup,
            style: const TextStyle(
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
              SwitchListTile(
                secondary: const Icon(Icons.sync, color: Colors.tealAccent),
                title: Text(
                  l10n.autoSyncTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  l10n.autoSyncSub,
                  style: const TextStyle(fontSize: 12),
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

                    final profileJsonString = jsonEncode(
                      profile.copyWith(isAutoSyncEnabled: true).toJson(),
                    );
                    final success = await ref
                        .read(driveSyncProvider)
                        .backupToCloud(profileJsonString);

                    if (!context.mounted) return;

                    Navigator.pop(context);

                    if (success) {
                      await ref
                          .read(userProfileProvider.notifier)
                          .updateField('isAutoSyncEnabled', true);

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.autoSyncEnabled,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      );
                    } else {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.autoSyncFailed),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  } else {
                    await ref
                        .read(userProfileProvider.notifier)
                        .updateField('isAutoSyncEnabled', false);
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                title: Text(
                  l10n.backupToDrive,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.backupOverwriteTitle),
                      content: Text(l10n.backupOverwriteContent),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            l10n.cancel,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.backupNowBtn),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    final profileJsonString = jsonEncode(profile.toJson());
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => SyncProgressDialog(
                        isBackup: true,
                        profileJson: profileJsonString,
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.green),
                title: Text(
                  l10n.restoreFromCloud,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l10n.restoreOverwriteTitle)),
                        ],
                      ),
                      content: Text(l10n.restoreOverwriteContent),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            l10n.cancel,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.restoreDataBtn),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const SyncProgressDialog(isBackup: false),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: Text(
                  l10n.deleteCloudBackup,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                subtitle: Text(l10n.deleteCloudBackupSub),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.deleteCloudDataTitle),
                        ],
                      ),
                      content: Text(l10n.deleteCloudDataContent),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            l10n.cancel,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.deleteBackupBtn),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        content: Row(
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: Text(l10n.deletingFromDrive)),
                          ],
                        ),
                      ),
                    );

                    final success = await ref
                        .read(driveSyncProvider)
                        .deleteCloudBackup();

                    if (context.mounted) Navigator.pop(context);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? l10n.cloudBackupDeleted
                                : l10n.failedToDeleteBackup,
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

      Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Text(
          l10n.dangerZone,
          style: const TextStyle(
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
          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
          title: Text(
            l10n.eraseAllData,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            l10n.eraseAllDataSub,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          onTap: () => _showWipeDataDialog(context, ref, l10n),
        ),
      ),
      const SizedBox(height: 40),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAndProfile)),
      // <-- FIX: Responsive LayoutBuilder
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // LANDSCAPE: Two Column Grid
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: leftColumnWidgets,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: rightColumnWidgets,
                  ),
                ),
              ],
            );
          }
          // PORTRAIT: Single Column List
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...leftColumnWidgets, ...rightColumnWidgets],
            ),
          );
        },
      ),
    );
  }

  void _showSliderDialog(
    BuildContext context,
    String title,
    double currentValue,
    double min,
    double max,
    Function(double) onSave,
    AppLocalizations l10n,
  ) {
    double tempValue = currentValue;
    final textController = TextEditingController(
      text: tempValue.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.updateTitle(title)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: textController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        setState(() => tempValue = parsed.clamp(min, max));
                      }
                    },
                  ),
                ),
                Slider(
                  value: tempValue,
                  min: min,
                  max: max,
                  onChanged: (val) {
                    setState(() {
                      tempValue = val;
                      textController.text = val.toInt().toString();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(tempValue);
                Navigator.pop(context);
              },
              child: Text(l10n.save),
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
    Map<String, String> options,
    Function(String) onSave,
    AppLocalizations l10n,
  ) {
    String tempValue = currentValue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.updateTitle(title)),
          content: RadioGroup<String>(
            groupValue: tempValue,
            onChanged: (val) {
              if (val != null) {
                setState(() => tempValue = val);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.entries
                  .map(
                    (entry) => RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(tempValue);
                Navigator.pop(context);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showWipeDataDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            l10n.factoryReset,
            style: const TextStyle(color: Colors.redAccent),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.factoryResetContent),
                const SizedBox(height: 16),
                Text(
                  l10n.typeDeleteToConfirm,
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: textController.text == 'DELETE'
                  ? () async {
                      await ref.read(databaseProvider).wipeAllUserData();
                      await ref
                          .read(userProfileProvider.notifier)
                          .updateField('hasOnboarded', false);

                      ref.invalidate(weeklyStatsProvider);

                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const WelcomeScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  : null,
              child: Text(l10n.eraseEverythingBtn),
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
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

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
  String _internalStatus = 'Starting...';
  bool _isProcessing = true;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    final syncService = ref.read(driveSyncProvider);

    await Future.delayed(const Duration(milliseconds: 300));

    if (widget.isBackup) {
      final success = await syncService.backupToCloud(
        widget.profileJson!,
        onStatus: (msg) {
          if (mounted) setState(() => _internalStatus = msg);
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = success;
          if (!success && _internalStatus == 'Starting...') {
            _internalStatus = 'Backup Failed.';
          }
        });
      }
    } else {
      final restoredJson = await syncService.restoreFromCloud(
        onStatus: (msg) {
          if (mounted) setState(() => _internalStatus = msg);
        },
      );

      if (mounted) {
        if (restoredJson != null) {
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
            _internalStatus = 'Restore Complete!';
          });
        } else {
          setState(() {
            _isProcessing = false;
            _isSuccess = false;
            if (_internalStatus == 'Starting...') {
              _internalStatus = 'Restore Failed.';
            }
          });
        }
      }
    }
  }

  String _getLocalizedStatus(AppLocalizations l10n) {
    if (_internalStatus == 'Starting...') return l10n.starting;
    if (_internalStatus == 'Backup Failed.') return l10n.backupFailed;
    if (_internalStatus == 'Restore Complete!') return l10n.restoreComplete;
    if (_internalStatus == 'Restore Failed.') return l10n.restoreFailed;
    return _internalStatus;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.isBackup ? l10n.cloudBackupTitle : l10n.cloudRestoreTitle,
      ),
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
            _getLocalizedStatus(l10n),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: _isProcessing ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        if (!_isProcessing)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ),
      ],
    );
  }
}
