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
            const SliverToBoxAdapter(child: _VolumeChart()),
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

class _VolumeChart extends ConsumerWidget {
  const _VolumeChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartDataAsync = ref.watch(weeklyStatsProvider);

    return chartDataAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => const SizedBox(
        height: 200,
        child: Center(child: Text('Chart Error')),
      ),
      data: (spots) {
        final hasData = spots.isNotEmpty && spots.any((spot) => spot.y > 0);

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
                    'Complete a workout to see your progress!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        // FIX: Find the highest volume to set a dynamic Y-axis ceiling
        double maxVolume = 0;
        for (var spot in spots) {
          if (spot.y > maxVolume) maxVolume = spot.y;
        }

        return Container(
          height: 200,
          // FIX: Add padding so the labels don't clip off the screen
          padding: const EdgeInsets.only(
            top: 24,
            right: 24,
            left: 16,
            bottom: 16,
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY:
                  maxVolume *
                  1.2, // FIX: Adds 20% headroom above the highest peak
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVolume > 0
                    ? (maxVolume / 4).ceilToDouble()
                    : 25,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.withAlpha(50), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                // FIX: Added left labels so you can actually see the Volume numbers!
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == maxVolume * 1.2) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value > 6) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime.now().subtract(
                        Duration(days: 6 - value.toInt()),
                      );
                      final dayNames = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          dayNames[date.weekday - 1],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting:
                      true, // FIX: Stops the line from dropping below zero
                  color: Theme.of(
                    context,
                  ).colorScheme.primary, // FIX: Better contrast on dark mode
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(
                    show: true,
                  ), // FIX: Draws explicit circles on data points
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withAlpha(50),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      'durationSeconds': details.targetDurationSeconds, // FIX: Added this back!
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
  handler.startWorkoutSequence(routine, workout.title, workout.id);

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
