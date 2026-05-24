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
  String _apiKey = '';

  void _nextPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage < 6) {
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
    final currentProfile = ref.read(userProfileProvider);

    final newProfile = UserProfile(
      hasOnboarded: true,
      appLocale: currentProfile.appLocale,
      themeMode: currentProfile.themeMode,
      gender: _gender,
      goal: _goal,
      preferredStyle: _preferredStyle.isEmpty ? 'Full Gym' : _preferredStyle,
      pushupCapacity: _pushups,
      pullupCapacity: _pullups,
      squatCapacity: _squats,
      heightCm: _height,
      weightKg: _weight,
      aiCredits: 2,
      isPro: false,
      customApiKey: _apiKey,
      customModelName: '',
      isAutoSyncEnabled: currentProfile.isAutoSyncEnabled,
    );
    await ref.read(userProfileProvider.notifier).saveProfile(newProfile);

    bool aiSuccess = false;

    while (!aiSuccess) {
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

        if (newProfile.isAutoSyncEnabled) {
          final profileJsonString = jsonEncode(newProfile.toJson());
          ref.read(driveSyncProvider).backupToCloud(profileJsonString).ignore();
        }

        aiSuccess = true; // Break the loop!

        if (!mounted) return;
        Navigator.pop(context); // Close loader
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loader

        final shouldRetry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Connection Interrupted'),
            content: Text(
              'We had trouble reaching the AI servers.\n\nError: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.skipAi,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: () => Navigator.pop(ctx, true),
                label: const Text('Try Again'),
              ),
            ],
          ),
        );

        // If they chose to skip, drop them into the dashboard without a plan
        if (shouldRetry != true) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
          break;
        }
      }
    }
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
                value: (_currentPage + 1) / 7, // <--- FIX 1: Bumped total to 6
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
                  _buildStylePage(l10n),
                  _buildAssessmentPage(l10n),
                  _buildMetricsPage(l10n),
                  _buildAiConfigPage(l10n),
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
          _SliderWithTextInput(
            value: _pushups.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: Colors.blueAccent,
            onChanged: (val) => setState(() => _pushups = val.toInt()),
          ),
          const SizedBox(height: 24),

          Text(
            l10n.assessPullups,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _SliderWithTextInput(
            value: _pullups.toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            activeColor: Colors.redAccent,
            onChanged: (val) => setState(() => _pullups = val.toInt()),
          ),
          const SizedBox(height: 24),

          Text(
            l10n.assessSquats,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _SliderWithTextInput(
            value: _squats.toDouble(),
            min: 0,
            max: 200,
            divisions: 100,
            activeColor: Colors.green,
            onChanged: (val) => setState(() => _squats = val.toInt()),
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
          _SliderWithTextInput(
            value: _height,
            min: 120,
            max: 220,
            divisions: 100,
            activeColor: Colors.blueAccent,
            suffix: 'cm',
            onChanged: (val) => setState(() => _height = val),
          ),
          const SizedBox(height: 32),

          Text(
            l10n.weightLabel,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          _SliderWithTextInput(
            value: _weight,
            min: 40,
            max: 150,
            divisions: 110,
            activeColor: Colors.blueAccent,
            suffix: 'kg',
            onChanged: (val) => setState(() => _weight = val),
          ),
          const SizedBox(height: 48),

          // FilledButton.icon(
          //   onPressed: () async {
          //     if (await AIGuard.check(context, ref)) {
          //       _finishOnboarding();
          //     }
          //   },
          //   icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
          //   style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
          //   label: Text(
          //     l10n.generateAiPlan,
          //     style: const TextStyle(fontSize: 16),
          //   ),
          // ),
          FilledButton(
            onPressed: _nextPage,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            child: const Text('Next', style: TextStyle(fontSize: 18)),
          ),
          // const SizedBox(height: 16),
          // TextButton(
          //   onPressed: _skipOnboarding,
          //   child: Text(
          //     l10n.skipAi,
          //     style: const TextStyle(fontSize: 16, color: Colors.grey),
          //   ),
          // ),
        ],
      ),
    );
  }

  // --- PAGE 7: AI CONFIGURATION (BYOK) ---
  Widget _buildAiConfigPage(AppLocalizations l10n) {
    return _PageTemplate(
      title: l10n.aiConfigTitle,
      subtitle:
          'To generate your free AI workout plans, please provide your own Gemini API Key.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to get your free key:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Go to Google AI Studio (aistudio.google.com)\n2. Tap "Get API key"\n3. Copy and paste it below.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: (val) => _apiKey = val,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.customGeminiKey,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key, color: Colors.deepPurpleAccent),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              if (_apiKey.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter an API Key, or skip this step.',
                    ),
                  ),
                );
                return;
              }
              _finishOnboarding();
            },
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // Hug contents tightly
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
              content,
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

// --- NEW INTERACTIVE SLIDER COMPONENT ---
class _SliderWithTextInput extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color activeColor;
  final String suffix;
  final ValueChanged<double> onChanged;

  const _SliderWithTextInput({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.activeColor,
    this.suffix = '',
    required this.onChanged,
  });

  @override
  State<_SliderWithTextInput> createState() => _SliderWithTextInputState();
}

class _SliderWithTextInputState extends State<_SliderWithTextInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toInt().toString());
  }

  @override
  void didUpdateWidget(covariant _SliderWithTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newValStr = widget.value.toInt().toString();
      if (_controller.text != newValStr) {
        _controller.text = newValStr;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            activeColor: widget.activeColor,
            onChanged: widget.onChanged,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110, // Enough room for the number and suffix
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              isDense: true,
              suffixText: widget.suffix,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                widget.onChanged(parsed.clamp(widget.min, widget.max));
              } else {
                // Revert to old value if they typed garbage
                _controller.text = widget.value.toInt().toString();
              }
            },
          ),
        ),
      ],
    );
  }
}
