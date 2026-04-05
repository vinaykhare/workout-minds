import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/workout_builder/manual_plan_builder_screen.dart';
import 'package:workout_minds/repositories/providers.dart';

class PlanDetailsScreen extends ConsumerWidget {
  final int planId;

  const PlanDetailsScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planDetailsProvider(planId));
    final scheduleAsync = ref.watch(planScheduleProvider(planId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // 1. Construct the map of existing workouts
              final plan = await ref.read(databaseProvider).getPlan(planId);
              final days = await ref
                  .read(databaseProvider)
                  .getPlanSchedule(planId);

              Map<int, Workout> currentSchedule = {};
              for (var row in days) {
                final dayData = row.readTable(
                  ref.read(databaseProvider).workoutPlanDays,
                );
                final workoutData = row.readTableOrNull(
                  ref.read(databaseProvider).workouts,
                );
                if (workoutData != null) {
                  currentSchedule[dayData.dayNumber] = workoutData;
                }
              }

              if (!context.mounted) return;

              // 2. Launch the Builder in Edit Mode
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManualPlanBuilderScreen(
                    existingPlanId: plan.id,
                    existingTitle: plan.title,
                    existingWeeks: plan.totalWeeks,
                    existingSchedule: currentSchedule,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Plan?'),
                  content: const Text(
                    'Are you sure you want to delete this workout plan? Your individual workouts will NOT be deleted.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete Plan'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await ref.read(databaseProvider).deletePlan(planId);
                ref.invalidate(plansStreamProvider); // Refresh Dashboard Plans
                if (context.mounted) {
                  Navigator.pop(context); // Go back to Dashboard
                }
              }
            },
          ),
        ],
      ),

      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading plan: $e')),
        data: (plan) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan.description ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Chip(
                        label: Text('${plan.totalWeeks} Weeks • ${plan.goal}'),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Schedule',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              scheduleAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, st) =>
                    SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
                data: (days) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final row = days[index];
                      final dayData = row.readTable(
                        ref.read(databaseProvider).workoutPlanDays,
                      );
                      final workoutData = row.readTableOrNull(
                        ref.read(databaseProvider).workouts,
                      );

                      final isRestDay = workoutData == null;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: isRestDay
                            ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha(100)
                            : null,
                        child: ListTile(
                          // Replaced the CircleAvatar with a structured Day Box
                          leading: Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isRestDay
                                  ? Colors.grey.withAlpha(30)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Day\n${dayData.dayNumber}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isRestDay
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          title: Text(
                            isRestDay ? 'Rest Day' : workoutData.title,
                            style: TextStyle(
                              fontWeight: isRestDay
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: isRestDay ? Colors.grey : null,
                            ),
                          ),
                          subtitle: dayData.notes != null
                              ? Text(dayData.notes!)
                              : null,
                          trailing: !isRestDay
                              ? const Icon(
                                  Icons.play_arrow,
                                  color: Colors.green,
                                )
                              : null,
                          onTap: isRestDay
                              ? null
                              : () {
                                  // Optional: Route to Active Workout Screen or Workout Details here!
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Starting ${workoutData.title}...',
                                      ),
                                    ),
                                  );
                                },
                        ),
                      );
                    }, childCount: days.length),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
