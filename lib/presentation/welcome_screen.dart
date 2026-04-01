import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/preferences_provider.dart';
import '../repositories/providers.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;
  String _statusText = '';

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Connecting to Google Drive...';
    });

    final syncService = ref.read(driveSyncProvider);
    final backupExists = await syncService.hasBackup();

    if (!mounted) return;

    if (!backupExists) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backup found. Let\'s start fresh!'),
          backgroundColor: Colors.orange,
        ),
      );
      _startFresh();
      return;
    }

    setState(() => _statusText = 'Restoring your profile and workouts...');
    final restoredJson = await syncService.restoreFromCloud();

    if (!mounted) return;

    if (restoredJson != null) {
      // 1. Rebuild and save the profile (Force Auto-Sync ON since they linked Drive!)
      final restoredProfile = UserProfile.fromJson(
        jsonDecode(restoredJson),
      ).copyWith(isAutoSyncEnabled: true);
      await ref.read(userProfileProvider.notifier).saveProfile(restoredProfile);

      // 2. Refresh the UI database connections
      ref.invalidate(databaseProvider);
      ref.invalidate(weeklyStatsProvider);
      ref.invalidate(recentWorkoutsProvider);
      ref.invalidate(workoutsStreamProvider);

      setState(() => _isLoading = false);

      // 3. Ask for their current weight!
      _showWeightConfirmation(restoredProfile.weightKg);
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore failed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- SMART UX: Confirm Weight Post-Restore ---
  void _showWeightConfirmation(double lastKnownWeight) {
    double currentWeight = lastKnownWeight;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Consumer(
          // <-- NEW: Grab a living 'ref' for the dialog!
          builder: (context, ref, child) => AlertDialog(
            title: const Text('Welcome Back! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'We successfully restored your workout history. Weight can change over time; are you still:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${currentWeight.toInt()} kg',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                Slider(
                  value: currentWeight,
                  min: 40,
                  max: 150,
                  onChanged: (val) => setState(() => currentWeight = val),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    // Use the fresh ref to update the weight
                    await ref
                        .read(userProfileProvider.notifier)
                        .updateField('weightKg', currentWeight);

                    if (dialogContext.mounted) {
                      // Do NOT push a new route! The Dashboard is already behind this dialog.
                      // Just pop the dialog and you are home!
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Looks Good!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startFresh() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If it's Windows or Web, immediately push to Onboarding (skip the welcome screen)
    if (kIsWeb || Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFresh());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // App Logo / Hero
              const Icon(
                Icons.fitness_center,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Workout Minds',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your AI-powered fitness journey, synced securely with Google Drive.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const Spacer(),

              if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              ] else ...[
                // Google Sign In Button
                FilledButton.icon(
                  onPressed: _handleRestore,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Restore from Google Drive'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Skip Button
                OutlinedButton(
                  onPressed: _startFresh,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'Start Fresh',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
