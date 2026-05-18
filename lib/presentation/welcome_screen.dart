import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;
  String _statusText = '';
  bool _hasSkippedSignIn = false; // Tracks the new Sign-In Step

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
      await ref
          .read(userProfileProvider.notifier)
          .updateField('isAutoSyncEnabled', true);
      _startFresh();
      return;
    }

    setState(() => _statusText = 'Restoring your profile and workouts...');
    final restoredJson = await syncService.restoreFromCloud();

    if (!mounted) return;

    if (restoredJson != null) {
      final restoredProfile = UserProfile.fromJson(
        jsonDecode(restoredJson),
      ).copyWith(isAutoSyncEnabled: true);
      await ref.read(userProfileProvider.notifier).saveProfile(restoredProfile);

      ref.invalidate(databaseProvider);
      ref.invalidate(weeklyStatsProvider);
      ref.invalidate(recentWorkoutsProvider);
      ref.invalidate(workoutsStreamProvider);

      setState(() => _isLoading = false);

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

  void _showWeightConfirmation(double lastKnownWeight) {
    double currentWeight = lastKnownWeight;
    final isHi = ref.read(userProfileProvider).appLocale == 'hi';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Consumer(
          builder: (context, ref, child) {
            final weightChanged = currentWeight != lastKnownWeight;
            final btnText = weightChanged
                ? (isHi ? 'Weight Update Karein' : 'Update Weight Now')
                : (isHi ? 'Sahi Hai!' : 'Looks Good!');

            return AlertDialog(
              title: Text(isHi ? 'Wapas Swagat Hai! 🎉' : 'Welcome Back! 🎉'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isHi
                        ? 'Aapki history mil gayi. Kya aapka wazan abhi bhi yahi hai?'
                        : 'We successfully restored your workout history. Is your weight still accurate?',
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
                      await ref
                          .read(userProfileProvider.notifier)
                          .updateField('weightKg', currentWeight);

                      final finalProfile = ref.read(userProfileProvider);
                      if (finalProfile.isAutoSyncEnabled) {
                        final profileJsonString = jsonEncode(
                          finalProfile.toJson(),
                        );
                        ref
                            .read(driveSyncProvider)
                            .backupToCloud(profileJsonString)
                            .ignore();
                      }

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const DashboardScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    child: Text(btnText),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _startFresh() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  // --- NEW: STEP 1 - SIGN IN UI ---
  Widget _buildSignInStep(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              Text(
                'Unlock AI Fitness',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in with Google to enable AI Workout Generation, Optimization, and Cloud Backups.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  final success = await ref.read(driveSyncProvider).signIn();
                  if (context.mounted) {
                    Navigator.pop(context); // Close loader
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sign in failed. Please try again.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.all(20),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _hasSkippedSignIn = true),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- EXISTING: STEP 2 - RESTORE UI ---
  Widget _buildRestoreStep(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final heroSection = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.fitness_center, size: 100, color: Colors.blueAccent),
        const SizedBox(height: 24),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.welcomeSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
        ),
      ],
    );

    final actionSection = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoading) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _handleRestore,
            icon: const Icon(Icons.cloud_download),
            label: Text(l10n.restoreGoogle),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.all(20),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _startFresh,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.all(20),
            ),
            child: Text(
              l10n.startFresh,
              style: TextStyle(color: onSurface, fontSize: 16),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > 600;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: isLandscape
                      ? Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Row(
                            children: [
                              Expanded(child: heroSection),
                              const SizedBox(width: 48),
                              Expanded(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 400,
                                    ),
                                    child: actionSection,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(),
                              heroSection,
                              const Spacer(),
                              actionSection,
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFresh());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = AppLocalizations.of(context)!;
    final authUser = ref.watch(authStateProvider).value;

    // STEP 1: Ask for Login if they haven't skipped it and aren't logged in
    if (authUser == null && !_hasSkippedSignIn) {
      return _buildSignInStep(context, l10n);
    }

    // STEP 2: Restore from Drive or Start Fresh
    return _buildRestoreStep(context, l10n);
  }
}
