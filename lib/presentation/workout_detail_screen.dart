import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
import 'package:workout_minds/repositories/providers.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the future provider we just created
    final detailsAsync = ref.watch(workoutDetailsProvider(workout.id));

    return Scaffold(
      appBar: AppBar(title: Text(workout.title)),
      body: detailsAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No exercises found.'));
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              // Extract the typed data from the Drift join
              final exercise = rows[index].readTable(
                ref.read(databaseProvider).exercises,
              );
              final details = rows[index].readTable(
                ref.read(databaseProvider).workoutExercises,
              );

              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(exercise.name),
                subtitle: Text('Muscle: ${exercise.muscleGroup}'),
                trailing: Text(
                  '${details.targetSets} Sets x ${details.targetReps} Reps',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading details: $e')),
      ),
      // Inside WorkoutDetailScreen's build method:
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final detailsAsync = ref.read(workoutDetailsProvider(workout.id));

          detailsAsync.maybeWhen(
            data: (rows) {
              final routine = rows.map((row) {
                final ex = row.readTable(ref.read(databaseProvider).exercises);
                final details = row.readTable(
                  ref.read(databaseProvider).workoutExercises,
                );
                return {
                  'name': ex.name,
                  'sets': details.targetSets,
                  'reps': details.targetReps,
                };
              }).toList();

              final handler = ref.read(audioHandlerProvider);
              handler.startWorkoutSequence(routine);

              // Navigate to the Active Workout Screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActiveWorkoutScreen(),
                ),
              );
            },
            orElse: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Still loading data...')),
              );
            },
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Workout'),
      ),
    );
  }
}
