import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/presentation/log_detail_screen.dart';
import 'package:workout_minds/repositories/providers.dart';

class RecentWorkoutsSection extends ConsumerWidget {
  const RecentWorkoutsSection({super.key});

  // Helper to make dates look nice (e.g., "Today", "Yesterday", or "Oct 12")
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;

    if (difference == 0) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (difference == 1) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

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
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentLogsAsync = ref.watch(recentWorkoutsProvider);

    return recentLogsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading history: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'No workouts logged yet.\nTime to crush your first one! 💪',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                'Recent History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.separated(
              shrinkWrap:
                  true, // IMPORTANT: Allows ListView to sit inside the Home scroll view
              physics:
                  const NeverScrollableScrollPhysics(), // Let the parent handle scrolling
              itemCount: logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                // FIX: Extract both tables from the joined result
                final row = logs[index];
                final log = row.readTable(
                  ref.read(databaseProvider).workoutLogs,
                );
                final workout = row.readTable(
                  ref.read(databaseProvider).workouts,
                );

                return Card(
                  elevation: 0,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withAlpha(80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    // FIX: Navigate to the beautiful new summary screen!
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LogDetailScreen(
                            log: log,
                            workoutTitle: workout.title,
                          ),
                        ),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      workout.title, // FIX: Real Workout Name!
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(log.executedAt),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber.shade600),
                        const SizedBox(height: 4),
                        const Text(
                          'Completed',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
