import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/presentation/settings_screen.dart';
import 'package:workout_minds/presentation/widgets/recent_workouts_section.dart';
import 'package:workout_minds/presentation/widgets/weekly_progress_card.dart';
import 'package:workout_minds/presentation/widgets/workout_list_section.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(dashboardControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    // Listen for background errors and show a SnackBar!
    ref.listen(dashboardControllerProvider, (previous, next) {
      if (next is AsyncError) {
        // Clean up the error text to look nice for the user
        final errorText = next.error.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final dashboardState = ref.watch(dashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        // FIX 1: Moved actions to the AppBar for a cleaner UI!
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Build Manually',
            onPressed: () {
              ref.read(workoutDraftProvider.notifier).loadExercises([]);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkoutBuilderScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: l10n.aiGenerate,
            onPressed: () => _showAiGenerator(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import Workout',
            onPressed: () async {
              final result = await ref
                  .read(workoutShareProvider)
                  .pickAndImportWorkout();
              if (result != null && context.mounted) {
                if (result == "Success") {
                  ref.invalidate(
                    dashboardControllerProvider,
                  ); // Refresh dashboard!
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Workout Imported!',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          // FIX: Added the Settings button!
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings & Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          workoutsAsync.when(
            data: (workouts) => LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: CustomScrollView(
                          slivers: [
                            const SliverToBoxAdapter(
                              child: WeeklyProgressCard(),
                            ),
                            const SliverToBoxAdapter(
                              child: RecentWorkoutsSection(),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: CustomScrollView(
                          slivers: [WorkoutListSection(workouts: workouts)],
                        ),
                      ),
                    ],
                  );
                }

                return CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: WeeklyProgressCard()),
                    const SliverToBoxAdapter(child: RecentWorkoutsSection()),
                    WorkoutListSection(workouts: workouts),
                  ],
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          l10n.errorPrefix("AI Generation Failed"),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Dismiss & Go Back'),
                      onPressed: () =>
                          ref.invalidate(dashboardControllerProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (dashboardState.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'AI is building your workout...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // floatingActionButton block is completely DELETED!
    );
  }

  void _showAiGenerator(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiGeneratorTitle),
        content: TextField(
          decoration: InputDecoration(
            hintText: l10n.aiGeneratorHint,
            helperText: l10n.aiGeneratorHelperText,
          ),
          controller: promptController,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final prompt = promptController.text.trim();
              ref
                  .read(dashboardControllerProvider.notifier)
                  .generateWorkout(prompt);
              Navigator.pop(context);
            },
            child: Text(l10n.generate),
          ),
        ],
      ),
    );
  }
}
