import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';

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
  String _experience = '';
  double _height = 170.0;
  double _weight = 70.0;

  void _nextPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage < 4) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    // 1. Show a loading overlay so they know something is happening
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating your first custom plan...'),
              ],
            ),
          ),
        ),
      ),
    );

    // 2. Trigger the AI to build a baseline routine
    try {
      final aiPrompt =
          "Create a perfectly balanced baseline workout based on my profile.";
      await ref
          .read(dashboardControllerProvider.notifier)
          .generateWorkout(aiPrompt);
    } catch (e) {
      // If there is no internet or the API is busy, we silently swallow the error.
      // The user will just land on an empty dashboard instead.
      // FIX: Temporarily print the exact reason it failed!
      // print('=== AI GENERATION FAILED DURING ONBOARDING ===');
      // print(e.toString());
      // print(stackTrace); // pass stackTrace after e in params
      // print('==============================================');
    }

    // 3. Remove the loading overlay
    if (mounted) Navigator.pop(context);

    // 4. Save the profile and trigger the routing gatekeeper to the Dashboard!
    final currentLocale = ref.read(userProfileProvider).appLocale;
    final newProfile = UserProfile(
      hasOnboarded: true,
      appLocale: currentLocale,
      gender: _gender,
      goal: _goal,
      experienceLevel: _experience,
      heightCm: _height,
      weightKg: _weight,
      aiCredits: 3, // Initialize their credits
      isPro: false,
      customApiKey: '',
      customModelName: '',
    );
    await ref.read(userProfileProvider.notifier).saveProfile(newProfile);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / 5, // 5 pages total
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
                  _buildLanguagePage(),
                  _buildGenderPage(l10n),
                  _buildGoalPage(),
                  _buildExperiencePage(),
                  _buildMetricsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PAGE 1: LANGUAGE ---
  Widget _buildLanguagePage() {
    final currentLocale = ref.watch(userProfileProvider).appLocale;

    return _PageTemplate(
      title: 'Choose Language\nBhasha Chunein',
      subtitle: 'How would you like the app to talk to you?',
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SelectionCard(
            title: 'English',
            subtitle: 'Standard English',
            icon: Icons.language,
            isSelected: currentLocale == 'en',
            onTap: () async {
              await ref
                  .read(userProfileProvider.notifier)
                  .updateField('appLocale', 'en');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Hinglish',
            subtitle: 'Conversational Indian English',
            icon: Icons.chat_bubble_outline,
            isSelected: currentLocale == 'hi',
            onTap: () async {
              await ref
                  .read(userProfileProvider.notifier)
                  .updateField('appLocale', 'hi');
              _nextPage();
            },
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
            title: 'Female',
            icon: Icons.female,
            isSelected: _gender == 'Female',
            onTap: () {
              setState(() => _gender = 'Female');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Other / Prefer not to say',
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
  Widget _buildGoalPage() {
    return _PageTemplate(
      title: "What is your primary goal?",
      subtitle: "We'll tailor your AI-generated workouts to focus on this.",
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SelectionCard(
            title: 'Lose Weight',
            icon: Icons.monitor_weight_outlined,
            isSelected: _goal == 'Lose Weight',
            onTap: () {
              setState(() => _goal = 'Lose Weight');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Build Muscle',
            icon: Icons.fitness_center,
            isSelected: _goal == 'Build Muscle',
            onTap: () {
              setState(() => _goal = 'Build Muscle');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Stay Fit & Active',
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

  // --- PAGE 4: EXPERIENCE ---
  Widget _buildExperiencePage() {
    return _PageTemplate(
      title: "What is your fitness level?",
      subtitle: "Ensures the exercises aren't too easy or too dangerous.",
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SelectionCard(
            title: 'Beginner',
            subtitle: 'Just starting out.',
            icon: Icons.battery_1_bar,
            isSelected: _experience == 'Beginner',
            onTap: () {
              setState(() => _experience = 'Beginner');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Intermediate',
            subtitle: 'I train somewhat consistently.',
            icon: Icons.battery_4_bar,
            isSelected: _experience == 'Intermediate',
            onTap: () {
              setState(() => _experience = 'Intermediate');
              _nextPage();
            },
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: 'Advanced',
            subtitle: 'I am a seasoned gym-goer.',
            icon: Icons.battery_full,
            isSelected: _experience == 'Advanced',
            onTap: () {
              setState(() => _experience = 'Advanced');
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // --- PAGE 5: METRICS ---
  Widget _buildMetricsPage() {
    return _PageTemplate(
      title: "Let's get your metrics",
      subtitle: "Used to calculate your BMI and daily caloric burn.",
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Height (cm)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          const Text(
            'Weight (kg)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          FilledButton(
            onPressed: _finishOnboarding,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('Finish Setup', style: TextStyle(fontSize: 18)),
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
    return Padding(
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
            Icon(icon, size: 32, color: isSelected ? primary : Colors.white),
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
                      color: isSelected ? primary : Colors.white,
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
