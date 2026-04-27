import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/dashboard_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _gender = '';
  String _goal = '';
  String _preferredStyle = ''; // <--- NEW: Added State Variable
  int _pushups = 5;
  int _pullups = 0;
  int _squats = 15;
  double _height = 170.0;
  double _weight = 70.0;

  void _nextPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage < 5) {
      // <--- FIX 1: Bumped to 5 because we now have 6 pages!
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final l10n = AppLocalizations.of(context)!;
    final currentProfile = ref.read(
      userProfileProvider,
    ); // Grab current to preserve AutoSync!

    final newProfile = UserProfile(
      hasOnboarded: true,
      appLocale: currentProfile.appLocale,
      themeMode: currentProfile.themeMode,
      gender: _gender,
      goal: _goal,
      preferredStyle: _preferredStyle.isEmpty
          ? 'Full Gym'
          : _preferredStyle, // Ensure fallback
      pushupCapacity: _pushups,
      pullupCapacity: _pullups,
      squatCapacity: _squats,
      heightCm: _height,
      weightKg: _weight,
      aiCredits: 3,
      isPro: false,
      customApiKey: '',
      customModelName: '',
      isAutoSyncEnabled: currentProfile
          .isAutoSyncEnabled, // <--- FIX: Preserve Drive Connection!
    );
    await ref.read(userProfileProvider.notifier).saveProfile(newProfile);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.generatingPlan),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final aiPrompt =
          "Create a perfectly balanced 4-week baseline workout plan based on my profile.";
      await ref
          .read(aiPlanRepositoryProvider)
          .generateAndSavePlan(aiPrompt, newProfile);
      ref.invalidate(plansStreamProvider);
      ref.invalidate(workoutsStreamProvider);
      // --- FIX 1: FIRE BACKGROUND SYNC AFTER ONBOARDING ---
      if (newProfile.isAutoSyncEnabled) {
        final profileJsonString = jsonEncode(newProfile.toJson());
        ref.read(driveSyncProvider).backupToCloud(profileJsonString).ignore();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Generation failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _skipOnboarding() async {
    final currentProfile = ref.read(userProfileProvider);

    final newProfile = UserProfile(
      hasOnboarded: true, // Gets them out of the Welcome loop!
      appLocale: currentProfile.appLocale,
      themeMode: currentProfile.themeMode,
      gender: _gender.isEmpty ? 'Other' : _gender,
      goal: _goal.isEmpty ? 'Stay Fit' : _goal,
      preferredStyle: _preferredStyle.isEmpty ? 'Full Gym' : _preferredStyle,
      pushupCapacity: _pushups,
      pullupCapacity: _pullups,
      squatCapacity: _squats,
      heightCm: _height,
      weightKg: _weight,
      aiCredits: currentProfile.aiCredits, // Preserve their 3 free credits!
      isPro: currentProfile.isPro,
      customApiKey: currentProfile.customApiKey,
      customModelName: currentProfile.customModelName,
      isAutoSyncEnabled: currentProfile.isAutoSyncEnabled,
    );

    await ref.read(userProfileProvider.notifier).saveProfile(newProfile);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              )
            : null,
        actions: [
          TextButton(
            onPressed: _skipOnboarding,
            child: Text(l10n.skip, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / 6, // <--- FIX 1: Bumped total to 6
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) =>
                    setState(() => _currentPage = page),
                children: [
                  _buildLanguagePage(l10n),
                  _buildGenderPage(l10n),
                  _buildGoalPage(l10n),
                  _buildStylePage(l10n), // <--- NEW: The Missing Style Page!
                  _buildAssessmentPage(l10n),
                  _buildMetricsPage(l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PAGE 1: LANGUAGE & THEME ---
  Widget _buildLanguagePage(AppLocalizations l10n) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    return _PageTemplate(
      title: 'Preferences', // You can localize this later if you want!
      subtitle: l10n.chooseLanguageSub,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectionCard(
            title: 'English',
            subtitle: 'Standard English',
            icon: Icons.language,
            isSelected: profile.appLocale == 'en',
            // FIX: Removed _nextPage() here!
            onTap: () => notifier.updateField('appLocale', 'en'),
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Hinglish',
            subtitle: 'Conversational Indian English',
            icon: Icons.chat_bubble_outline,
            isSelected: profile.appLocale == 'hi',
            // FIX: Removed _nextPage() here!
            onTap: () => notifier.updateField('appLocale', 'hi'),
          ),
          const SizedBox(height: 48),

          // --- THEME SELECTOR ---
          Text(
            l10n.themeTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'system',
                icon: const Icon(Icons.settings_suggest),
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: 'light',
                icon: const Icon(Icons.light_mode),
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(
                value: 'dark',
                icon: const Icon(Icons.dark_mode),
                label: Text(l10n.themeDark),
              ),
            ],
            selected: {profile.themeMode},
            onSelectionChanged: (set) =>
                notifier.updateField('themeMode', set.first),
          ),
          const SizedBox(height: 48),

          // The user clicks this when they are done!
          FilledButton(
            onPressed: _nextPage,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            child: const Text('Next', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // --- PAGE 2: GENDER ---
  Widget _buildGenderPage(AppLocalizations l10n) {
    return _PageTemplate(
      title: l10n.genderTitle,
      subtitle: l10n.genderSubtitle,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SelectionCard(
            title: l10n.genderMale,
            icon: Icons.male,
            isSelected: _gender == 'Male',
            onTap: () {
              setState(() => _gender = 'Male');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: l10n.genderFemale,
            icon: Icons.female,
            isSelected: _gender == 'Female',
            onTap: () {
              setState(() => _gender = 'Female');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: l10n.genderOther,
            icon: Icons.person,
            isSelected: _gender == 'Other',
            onTap: () {
              setState(() => _gender = 'Other');
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // --- PAGE 3: GOAL ---
  Widget _buildGoalPage(AppLocalizations l10n) {
    return _PageTemplate(
      title: l10n.goalTitle,
      subtitle: l10n.goalSub,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SelectionCard(
            title: l10n.goalWeight,
            icon: Icons.monitor_weight_outlined,
            isSelected: _goal == 'Lose Weight',
            onTap: () {
              setState(() => _goal = 'Lose Weight');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: l10n.goalMuscle,
            icon: Icons.fitness_center,
            isSelected: _goal == 'Build Muscle',
            onTap: () {
              setState(() => _goal = 'Build Muscle');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: l10n.goalFit,
            icon: Icons.directions_run,
            isSelected: _goal == 'Stay Fit',
            onTap: () {
              setState(() => _goal = 'Stay Fit');
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // --- PAGE 4: STYLE / EQUIPMENT ---
  Widget _buildStylePage(AppLocalizations l10n) {
    return _PageTemplate(
      title: l10n.styleTitle,
      subtitle: 'What equipment do you have access to?',
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SelectionCard(
            title: l10n.styleGym,
            icon: Icons.domain,
            isSelected: _preferredStyle == 'Full Gym',
            onTap: () {
              setState(() => _preferredStyle = 'Full Gym');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: l10n.styleDumbbell,
            icon: Icons.fitness_center,
            isSelected: _preferredStyle == 'Home (Dumbbells/Bands)',
            onTap: () {
              setState(() => _preferredStyle = 'Home (Dumbbells/Bands)');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: l10n.styleBodyweight,
            icon: Icons.accessibility_new,
            isSelected: _preferredStyle == 'Bodyweight Only',
            onTap: () {
              setState(() => _preferredStyle = 'Bodyweight Only');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: l10n.styleYoga,
            icon: Icons.self_improvement,
            isSelected: _preferredStyle == 'Yoga & Flexibility',
            onTap: () {
              setState(() => _preferredStyle = 'Yoga & Flexibility');
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // --- PAGE 5: PHYSICAL ASSESSMENT ---
  Widget _buildAssessmentPage(AppLocalizations l10n) {
    return _PageTemplate(
      title: l10n.assessTitle,
      subtitle: l10n.assessSub,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.assessPushups,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _pushups.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => setState(() => _pushups = val.toInt()),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_pushups',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            l10n.assessPullups,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _pullups.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 50,
                  activeColor: Colors.redAccent,
                  onChanged: (val) => setState(() => _pullups = val.toInt()),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_pullups',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            l10n.assessSquats,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _squats.toDouble(),
                  min: 0,
                  max: 200,
                  divisions: 100,
                  activeColor: Colors.green,
                  onChanged: (val) => setState(() => _squats = val.toInt()),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_squats',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          FilledButton(
            onPressed: _nextPage,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            child: const Text('Next', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // --- PAGE 6: METRICS ---
  Widget _buildMetricsPage(AppLocalizations l10n) {
    return _PageTemplate(
      title: l10n.metricsTitle,
      subtitle: l10n.metricsSub,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.heightLabel,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _height,
                  min: 120,
                  max: 220,
                  divisions: 100,
                  onChanged: (val) => setState(() => _height = val),
                ),
              ),
              Text(
                '${_height.toInt()} cm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            l10n.weightLabel,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _weight,
                  min: 40,
                  max: 150,
                  divisions: 110,
                  onChanged: (val) => setState(() => _weight = val),
                ),
              ),
              Text(
                '${_weight.toInt()} kg',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _finishOnboarding,
            icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            label: Text(
              l10n.generateAiPlan,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _skipOnboarding,
            child: Text(
              l10n.skipAi,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _PageTemplate extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget content;

  const _PageTemplate({
    required this.title,
    required this.subtitle,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              SliverFillRemaining(hasScrollBody: false, child: content),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? primary.withAlpha(40) : surface.withAlpha(100),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isSelected ? primary : onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primary : onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: const TextStyle(color: Colors.grey)),
                  ],
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: primary),
          ],
        ),
      ),
    );
  }
}
