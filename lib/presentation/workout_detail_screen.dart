import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database.dart';
import '../repositories/providers.dart';

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
          if (rows.isEmpty) return const Center(child: Text('No exercises found.'));

          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              // Extract the typed data from the Drift join
              final exercise = rows[index].readTable(ref.read(databaseProvider).exercises);
              final details = rows[index].readTable(ref.read(databaseProvider).workoutExercises);

              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(exercise.name),
                subtitle: Text('Muscle: ${exercise.muscleGroup}'),
                trailing: Text('${details.targetSets} Sets x ${details.targetReps} Reps',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading details: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Sprint 2: This will trigger the AudioHandler and FSM
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout Player coming in Sprint 2!')),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Workout'),
      ),
    );
  }
}