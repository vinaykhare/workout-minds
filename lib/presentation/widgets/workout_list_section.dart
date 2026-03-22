import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/presentation/workout_detail_screen.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';

class WorkoutListSection extends ConsumerWidget {
  final List<Workout> workouts;
  const WorkoutListSection({super.key, required this.workouts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'My Routines',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          );
        }

        final workout = workouts[index - 1];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              workout.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(workout.difficultyLevel),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutDetailScreen(workout: workout),
                ),
              );
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.green,
                    size: 36,
                  ),
                  onPressed: () => _startWorkoutDirectly(
                    context,
                    ref,
                    workout.id,
                  ), // FIX 4: Re-linked!
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await ref
                          .read(databaseProvider)
                          .deleteWorkout(workout.id);
                      ref.invalidate(dashboardControllerProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Workout deleted.')),
                      );
                    } else if (value == 'edit') {
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
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }, childCount: workouts.length + 1),
    );
  }

  // --- HELPER METHODS MOVED HERE ---
  Future<void> _startWorkoutDirectly(
    BuildContext context,
    WidgetRef ref,
    int workoutId,
  ) async {
    final db = ref.read(databaseProvider);
    final rows = await db.getWorkoutDetails(workoutId);
    if (!context.mounted) return;

    final routine = rows.map((row) {
      final ex = row.readTable(db.exercises);
      final details = row.readTable(db.workoutExercises);
      return {
        'name': ex.name,
        'sets': details.targetSets,
        'reps': details.targetReps,
        'durationSeconds': details.targetDurationSeconds,
        'restSecondsSet': details.restSecondsAfterSet,
        'restSecondsExercise': details.restSecondsAfterExercise,
        'imageUrl': ex.imageUrl,
        'localImagePath': ex.localImagePath,
      };
    }).toList();

    final handler = ref.read(audioHandlerProvider);
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
}
