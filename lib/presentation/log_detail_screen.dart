import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database.dart';
import '../repositories/providers.dart';

class LogDetailScreen extends ConsumerWidget {
  final WorkoutLog log;
  final String workoutTitle;

  const LogDetailScreen({
    super.key,
    required this.log,
    required this.workoutTitle,
  });

  String _formatTime(int totalSeconds) {
    final int mins = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
    if (mins > 0) return '${mins}m';
    return '${secs}s';
  }

  // Formats date to "Oct 24, 2025 at 8:30 AM"
  String _formatDateTime(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We use the linked workoutId to fetch the exact routine they completed
    final detailsAsync = ref.watch(workoutDetailsProvider(log.workoutId));

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Summary')),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Text('No exercises found for this log.'),
            );
          }

          return CustomScrollView(
            slivers: [
              // --- HEADER SECTION ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 80,
                        color: Colors.amber.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        workoutTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(log.executedAt),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Exercises Completed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- EXERCISE LIST SECTION ---
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final row = rows[index];
                  final ex = row.readTable(
                    ref.read(databaseProvider).exercises,
                  );
                  final details = row.readTable(
                    ref.read(databaseProvider).workoutExercises,
                  );
                  final isDuration = (details.targetDurationSeconds ?? 0) > 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withAlpha(100),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
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
                                ? Image.network(ex.imageUrl!, fit: BoxFit.cover)
                                : const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ), // Checkmark for completed!
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                                // FIX: Actually use the _formatTime method to show rest periods!
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 14,
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
                  );
                }, childCount: rows.length),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ), // Bottom padding
            ],
          );
        },
      ),
    );
  }
}
