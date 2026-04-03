import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart'; // NEW: For PlaybackState
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
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
        // FIX: Add a blank SizedBox at the very end of the list so the FAB doesn't cover the last item!
        if (index == workouts.length + 1) {
          return const SizedBox(height: 100);
        }

        final workout = workouts[index - 1];

        // FIX 2: StreamBuilder to dynamically highlight the active workout!
        return StreamBuilder<PlaybackState>(
          stream: ref.read(audioHandlerProvider).playbackState,
          builder: (context, snapshot) {
            final handler = ref.read(audioHandlerProvider);
            final isPlayingSomething =
                snapshot.data?.processingState != AudioProcessingState.idle;
            final isActive =
                isPlayingSomething && handler.currentWorkoutId == workout.id;

            return Card(
              // Add a green border if it's the active workout
              shape: isActive
                  ? RoundedRectangleBorder(
                      side: BorderSide(color: Colors.green.shade500, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  workout.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isActive
                      ? '${workout.difficultyLevel}  •  ACTIVE'
                      : workout.difficultyLevel,
                  style: TextStyle(
                    color: isActive ? Colors.green.shade400 : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
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
                    IconButton(
                      icon: Icon(
                        // Swap to a resume/play icon dynamically
                        isActive ? Icons.refresh : Icons.play_circle_fill,
                        color: isActive ? Colors.greenAccent : Colors.green,
                        size: 36,
                      ),
                      onPressed: () => _startWorkoutDirectly(
                        context,
                        ref,
                        workout.id,
                        workout.title,
                      ),
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
                        } else if (value == 'share') {
                          final success = await ref
                              .read(workoutShareProvider)
                              .exportAndShare(workout.id);
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Export Failed')),
                            );
                          }
                        } else if (value == 'download') {
                          final success = await ref
                              .read(workoutShareProvider)
                              .saveToDisk(workout.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Workout saved to device!'),
                              ),
                            );
                          }
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
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.ios_share, size: 20),
                              SizedBox(width: 8),
                              Text('Share'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Download'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
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
          },
        );
      }, childCount: workouts.length + 2),
    );
  }

  // --- HELPER METHODS ---
  Future<void> _startWorkoutDirectly(
    BuildContext context,
    WidgetRef ref,
    int workoutId,
    String targetWorkoutTitle,
  ) async {
    final handler = ref.read(audioHandlerProvider);
    final pbState = handler.playbackState.value;
    final isPlayingSomething =
        pbState.processingState != AudioProcessingState.idle;

    // FIX: Unified Dialog for both "End & Start New" AND "Restart Active"
    if (isPlayingSomething && handler.currentWorkoutId != null) {
      final isSameWorkout = handler.currentWorkoutId == workoutId;
      final activeTitle = handler.mediaItem.value?.album ?? 'Active Workout';
      final dialogTitle = isSameWorkout
          ? 'Restart Workout?'
          : 'End Active Workout?';
      final dialogContent = isSameWorkout
          ? 'Are you sure you want to restart "$targetWorkoutTitle" from the beginning?'
          : 'Are you sure you want to end your active workout "$activeTitle" and start "$targetWorkoutTitle"?';
      final confirmBtnText = isSameWorkout ? 'Restart' : 'End & Start New';

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(confirmBtnText),
            ),
          ],
        ),
      );

      // If they click cancel or tap outside, abort!
      if (confirm != true) return;
    }

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

    final workout = await (db.select(
      db.workouts,
    )..where((t) => t.id.equals(workoutId))).getSingle();
    final appLocale = ref.read(userProfileProvider).appLocale;
    handler.startWorkoutSequence(routine, workout.title, workout.id, appLocale);

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
