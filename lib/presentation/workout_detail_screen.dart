import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'active_workout_screen.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  // FIX: Upgraded format time to exactly match the builder
  String _formatTime(int totalSeconds) {
    final int mins = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
    if (mins > 0) return '${mins}m';
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(workoutDetailsProvider(workout.id));

    return Scaffold(
      appBar: AppBar(title: Text(workout.title)),
      body: detailsAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Text('No exercises found in this workout.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100), // Space for FAB
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final ex = row.readTable(ref.read(databaseProvider).exercises);
              final details = row.readTable(
                ref.read(databaseProvider).workoutExercises,
              );

              final isLast = index == rows.length - 1;
              final isDuration = (details.targetDurationSeconds ?? 0) > 0;
              final restNext = details.restSecondsAfterExercise;

              return Column(
                children: [
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // THUMBNAIL IMAGE
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: ex.localImagePath != null
                                ? Image.file(
                                    File(ex.localImagePath!),
                                    fit: BoxFit.cover,
                                  )
                                : (ex.imageUrl != null &&
                                      ex.imageUrl!.isNotEmpty)
                                ? Image.network(
                                    ex.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                  )
                                : const Icon(
                                    Icons.fitness_center,
                                    color: Colors.grey,
                                  ),
                          ),
                          const SizedBox(width: 16),

                          // EXERCISE DETAILS
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // FIX: Dynamic Subtitle for Reps/Time
                                Text(
                                  isDuration
                                      ? '${details.targetSets} Sets x ${details.targetDurationSeconds}s'
                                      : '${details.targetSets} Sets x ${details.targetReps} Reps',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Rest between sets: ${_formatTime(details.restSecondsAfterSet)}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // FIX: The visual Rest Timer Arrow (Outside the card!)
                  if (!isLast && restNext > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rest ${_formatTime(restNext)} before next exercise',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final rows = detailsAsync.value;
          if (rows == null || rows.isEmpty) return;

          final routine = rows.map((row) {
            final ex = row.readTable(ref.read(databaseProvider).exercises);
            final details = row.readTable(
              ref.read(databaseProvider).workoutExercises,
            );
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
          handler.startWorkoutSequence(routine, workout.title, workout.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ActiveWorkoutScreen(),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Workout'),
      ),
    );
  }
}
