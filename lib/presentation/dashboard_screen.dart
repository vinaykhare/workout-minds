import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/presentation/settings_screen.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
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
    // 1. The variables are declared here
    final workoutsAsync = ref.watch(dashboardControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final dashboardState = ref.watch(dashboardControllerProvider);

    // Listen for background errors and show a SnackBar!
    ref.listen(dashboardControllerProvider, (previous, next) {
      if (next is AsyncError) {
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

    // --- FIX 2: Listen for Pending File Imports ---
    ref.listen<Map<String, dynamic>?>(pendingImportProvider, (previous, next) {
      if (next != null) {
        // 1. Erase the pending file from state immediately so we don't open it twice!
        Future.microtask(
          () => ref.read(pendingImportProvider.notifier).state = null,
        );

        // 2. Parse the data
        final title = next['workout']['title'] ?? 'Imported Workout';
        final exercisesData = next['exercises'] as List<dynamic>;

        final draftExercises = exercisesData.map((exData) {
          return DraftExercise(
            name: exData['name'],
            sets: exData['targetSets'],
            reps: exData['targetReps'] ?? 10,
            durationSeconds: exData['targetDurationSeconds'] ?? 30,
            isDuration: exData['targetDurationSeconds'] != null,
            restSecondsSet: exData['restSecondsAfterSet'] ?? 60,
            restSecondsExercise: exData['restSecondsAfterExercise'] ?? 90,
            imageUrl: exData['imageUrl'],
          );
        }).toList();

        // 3. Load into Riverpod
        ref.read(workoutDraftProvider.notifier).loadExercises(draftExercises);

        // 4. Safely Navigate!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WorkoutBuilderScreen(existingTitle: "$title (Imported)"),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        // 2. l10n used here
        title: GestureDetector(
          onTap: () {
            // Instantly re-fetches all workouts from the Drift database!
            ref.invalidate(dashboardControllerProvider);

            // Optional: Give the user a tiny visual confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dashboard Refreshed'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Image.asset("assets/images/app_logo.png", height: 40),
        ),
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
            // 3. l10n and _showAiGenerator used here
            tooltip: l10n.aiGenerate,
            onPressed: () => _showAiGenerator(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import Workout',
            onPressed: () async {
              // 1. Pick and Parse the file
              final workoutData = await ref
                  .read(workoutShareProvider)
                  .pickAndImportWorkout();

              if (workoutData != null && context.mounted) {
                final title =
                    workoutData['workout']['title'] ?? 'Imported Workout';
                final exercisesData = workoutData['exercises'] as List<dynamic>;

                // 2. Map into DraftExercises
                final draftExercises = exercisesData.map((exData) {
                  return DraftExercise(
                    name: exData['name'],
                    sets: exData['targetSets'],
                    reps: exData['targetReps'] ?? 10,
                    durationSeconds: exData['targetDurationSeconds'] ?? 30,
                    isDuration: exData['targetDurationSeconds'] != null,
                    restSecondsSet: exData['restSecondsAfterSet'] ?? 60,
                    restSecondsExercise:
                        exData['restSecondsAfterExercise'] ?? 90,
                    imageUrl: exData['imageUrl'],
                  );
                }).toList();

                // 3. Load into Riverpod
                ref
                    .read(workoutDraftProvider.notifier)
                    .loadExercises(draftExercises);

                // 4. Push to Builder Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutBuilderScreen(
                      existingTitle: "$title (Imported)",
                    ),
                  ),
                );
              } else if (context.mounted) {
                // Optional: Show an error if they picked an invalid file
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid file or import canceled.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
          ),
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
          // 4. workoutsAsync used here
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
          // 5. dashboardState used here
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
      // 6. The Dynamic Active Workout Button!
      floatingActionButton: StreamBuilder<PlaybackState>(
        stream: ref.read(audioHandlerProvider).playbackState,
        builder: (context, snapshot) {
          final state = snapshot.data;

          if (state != null &&
              state.processingState != AudioProcessingState.idle) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveWorkoutScreen(),
                  ),
                );
              },
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.fitness_center),
              label: const Text(
                'Resume Active Workout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
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
