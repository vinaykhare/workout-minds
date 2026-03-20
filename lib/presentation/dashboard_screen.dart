import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/presentation/workout_detail_screen.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(dashboardControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: workoutsAsync.when(
        data: (workouts) => CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _VolumeChart(hasData: false)),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final workout = workouts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      workout.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(workout.difficultyLevel),
                    // Action 1: Tap to open Details
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WorkoutDetailScreen(workout: workout),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Action 2: Play to Start Workout instantly
                        IconButton(
                          icon: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.green,
                            size: 36,
                          ),
                          onPressed: () =>
                              _startWorkoutDirectly(context, ref, workout.id),
                        ),
                        // Action 3: Edit / Delete Menu
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              await ref
                                  .read(databaseProvider)
                                  .deleteWorkout(workout.id);
                              ref.invalidate(dashboardControllerProvider);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Workout deleted.'),
                                ),
                              );
                            } else if (value == 'edit') {
                              // FIX 4: Pass the whole workout object
                              _openEditorWithData(context, ref, workout);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: workouts.length),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        // FIX: Replaced the static error text with a dismissible Error View
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
                Text(
                  l10n.errorPrefix("AI Generation Failed"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                  onPressed: () {
                    // This resets the provider, clearing the error and reloading the DB!
                    ref.invalidate(dashboardControllerProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_note),
            label: const Text('Build Manually'),
            onPressed: () {
              // FIX 3: Clear any old draft data before opening a fresh builder
              ref.read(workoutDraftProvider.notifier).loadExercises([]);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkoutBuilderScreen(),
                ),
              );
            },
          ),
          FloatingActionButton.extended(
            onPressed: () => _showAiGenerator(context, ref),
            label: Text(l10n.aiGenerate),
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
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

class _VolumeChart extends StatelessWidget {
  final bool hasData;

  const _VolumeChart({this.hasData = false});

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No workout data yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the button below to generate your first plan.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(0, 1),
                const FlSpot(1, 3),
                const FlSpot(2, 2),
              ],
              isCurved: true,
              color: Theme.of(context).primaryColor,
              barWidth: 4,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// HELPER METHODS (Fixed Async Gaps)
// -------------------------------------------------------------
// -------------------------------------------------------------
// HELPER METHODS
// -------------------------------------------------------------

// -------------------------------------------------------------
// HELPER METHODS (Strict Async Gap Compliance)
// -------------------------------------------------------------

Future<void> _startWorkoutDirectly(
  BuildContext context,
  WidgetRef ref,
  int workoutId,
) async {
  // final l10n = AppLocalizations.of(context)!;
  final db = ref.read(databaseProvider);

  final rows = await db.getWorkoutDetails(workoutId);

  // FIX: Placed immediately after the async gap
  if (!context.mounted) return;

  final routine = rows.map((row) {
    final ex = row.readTable(db.exercises);
    final details = row.readTable(db.workoutExercises);
    return {
      'name': ex.name,
      'sets': details.targetSets,
      'reps': details.targetReps,
      'restSecondsSet': details.restSecondsAfterSet,
      'restSecondsExercise': details.restSecondsAfterExercise,
      'imageUrl': ex.imageUrl,
      'localImagePath': ex.localImagePath,
    };
  }).toList();

  final handler = ref.read(audioHandlerProvider);
  // Pass the title (fetch it from the DB first if you only have workoutId)
  final workout = await (db.select(
    db.workouts,
  )..where((t) => t.id.equals(workoutId))).getSingle();
  handler.startWorkoutSequence(routine, workout.title);

  if (!context.mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()),
  );
}

Future<void> _openEditorWithData(
  BuildContext context,
  WidgetRef ref,
  Workout workout,
) async {
  final db = ref.read(databaseProvider);

  final rows = await db.getWorkoutDetails(workout.id);

  // FIX: Placed immediately after the async gap
  if (!context.mounted) return;

  final draftExercises = rows.map((row) {
    final ex = row.readTable(db.exercises);
    final details = row.readTable(db.workoutExercises);
    return DraftExercise(
      name: ex.name,
      sets: details.targetSets,
      reps: details.targetReps ?? 10,
      durationSeconds: details.targetDurationSeconds ?? 30,
      isDuration: details.targetDurationSeconds != null,
      restSecondsSet: details.restSecondsAfterSet,
      restSecondsExercise: details.restSecondsAfterExercise,
      imageUrl: ex.imageUrl,
      localImagePath: ex.localImagePath,
    );
  }).toList();

  ref.read(workoutDraftProvider.notifier).loadExercises(draftExercises);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WorkoutBuilderScreen(
        existingWorkoutId: workout.id,
        existingTitle: workout.title,
      ),
    ),
  );
}
