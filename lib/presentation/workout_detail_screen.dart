import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'active_workout_screen.dart';

// FIX: Converted to Stateful to manage the loading dialog
class WorkoutDetailScreen extends ConsumerStatefulWidget {
  final Workout workout;
  final int? planId; // <--- NEW
  final int? planDayId;

  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    this.planId,
    this.planDayId,
  });

  @override
  ConsumerState<WorkoutDetailScreen> createState() =>
      _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends ConsumerState<WorkoutDetailScreen> {
  String _formatTime(int totalSeconds) {
    final int mins = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
    if (mins > 0) return '${mins}m';
    return '${secs}s';
  }

  // --- NEW: Optimization Trigger ---
  Future<void> _handleOptimizeWorkout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Analyzing your feedback...\nOptimizing this workout...',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    try {
      final profile = ref.read(userProfileProvider);
      await ref
          .read(aiRepositoryProvider)
          .optimizeWorkout(widget.workout.id, profile);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ref.invalidate(workoutDetailsProvider(widget.workout.id));
        ref.invalidate(workoutsStreamProvider); // Refresh dashboard list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Workout Optimized Successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(workoutDetailsProvider(widget.workout.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.workout.title)),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (rows) {
          // FIX: Swapped ListView for CustomScrollView so we can add the button at the top!
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                      label: const Text(
                        'Optimize Workout based on Feedback',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.amber.withAlpha(30),
                        foregroundColor: Colors.amber,
                      ),
                      onPressed: _handleOptimizeWorkout,
                    ),
                  ),
                ),
              ),

              if (rows.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No exercises found in this workout.'),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final row = rows[index];
                    final ex = row.readTable(
                      ref.read(databaseProvider).exercises,
                    );
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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

                                      // EQUIPMENT & WEIGHT BADGE
                                      if ((ex.equipment != null &&
                                              ex.equipment!.isNotEmpty) ||
                                          details.targetWeight != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6.0,
                                          ),
                                          child: Text(
                                            [
                                              if (ex.equipment != null &&
                                                  ex.equipment!.isNotEmpty)
                                                ex.equipment,
                                              if (details.targetWeight != null)
                                                '${details.targetWeight} kg',
                                            ].join('  •  '),
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
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
                  }, childCount: rows.length),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100), // Gives the FAB plenty of room!
              ),
            ],
          );
        },
      ),

      floatingActionButton: StreamBuilder<PlaybackState>(
        stream: ref.read(audioHandlerProvider).playbackState,
        builder: (context, snapshot) {
          final handler = ref.read(audioHandlerProvider);
          final isPlayingSomething =
              snapshot.data?.processingState != AudioProcessingState.idle;
          final isActive =
              isPlayingSomething &&
              handler.currentWorkoutId == widget.workout.id;

          return FloatingActionButton.extended(
            onPressed: () async {
              if (isPlayingSomething && handler.currentWorkoutId != null) {
                final isSameWorkout =
                    handler.currentWorkoutId == widget.workout.id;
                final activeTitle =
                    handler.mediaItem.value?.album ?? 'Active Workout';

                final dialogTitle = isSameWorkout
                    ? 'Restart Workout?'
                    : 'End Active Workout?';
                final dialogContent = isSameWorkout
                    ? 'Are you sure you want to restart "${widget.workout.title}" from the beginning?'
                    : 'Are you sure you want to end your active workout "$activeTitle" and start "${widget.workout.title}"?';
                final confirmBtnText = isSameWorkout
                    ? 'Restart'
                    : 'End & Start New';

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
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: Text(confirmBtnText),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;
              }

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
                  'equipment': ex.equipment,
                  'targetWeight': details.targetWeight,
                  'instructions': ex.instructions,
                };
              }).toList();

              final appLocale = ref.read(userProfileProvider).appLocale;
              handler.startWorkoutSequence(
                routine,
                widget.workout.title,
                widget.workout.id,
                appLocale,
                planId: widget.planId, // <--- ADD THIS
                planDayId: widget.planDayId, // <--- ADD THIS
              );
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActiveWorkoutScreen(),
                ),
              );
            },
            icon: Icon(isActive ? Icons.restart_alt : Icons.play_arrow),
            label: Text(isActive ? 'Restart Workout' : 'Start Workout'),
          );
        },
      ),
    );
  }
}
