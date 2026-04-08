import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/workout_builder/manual_plan_builder_screen.dart';
import 'package:workout_minds/presentation/workout_detail_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'plan_countdown_screen.dart';

class PlanDetailsScreen extends ConsumerStatefulWidget {
  final int planId;
  const PlanDetailsScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends ConsumerState<PlanDetailsScreen> {
  // --- HELPER: FORMAT DATES ---
  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // --- OPTIMIZE LOGIC ---
  Future<void> _handleOptimizePlan() async {
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
              'Analyzing your feedback...\nOptimizing your plan...',
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
          .read(aiPlanRepositoryProvider)
          .optimizePlan(widget.planId, profile);

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(planDetailsProvider);
        ref.invalidate(planScheduleProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Plan Optimized Successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- THE SMART CALENDAR LOGIC (Push to Countdown) ---
  void _handlePlayPlan(WorkoutPlan plan, List<dynamic> days) async {
    final db = ref.read(databaseProvider);

    var nextUndoneRow = days
        .where((r) => !r.readTable(db.workoutPlanDays).isCompleted)
        .firstOrNull;

    if (nextUndoneRow == null) {
      return; // Should be handled by UI showing "Complete Plan" instead
    }

    final dayData = nextUndoneRow.readTable(db.workoutPlanDays);
    final workoutData = nextUndoneRow.readTableOrNull(db.workouts);

    final cleanToday = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var activeStartDate = plan.startDate;

    if (activeStartDate == null) {
      activeStartDate = cleanToday;
      await (db.update(
        db.workoutPlans,
      )..where((t) => t.id.equals(plan.id))).write(
        WorkoutPlansCompanion(startDate: drift.Value(activeStartDate)),
      );
      ref.invalidate(planDetailsProvider(plan.id));
      if (!mounted) return;
    }

    var targetDate = activeStartDate.add(Duration(days: dayData.dayNumber - 1));
    var cleanTarget = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    if (cleanTarget.isBefore(cleanToday)) {
      activeStartDate = cleanToday.subtract(
        Duration(days: dayData.dayNumber - 1),
      );
      await (db.update(
        db.workoutPlans,
      )..where((t) => t.id.equals(plan.id))).write(
        WorkoutPlansCompanion(startDate: drift.Value(activeStartDate)),
      );
      ref.invalidate(planDetailsProvider(plan.id));
      cleanTarget = cleanToday;
      if (!mounted) return;
    }

    if (cleanTarget.isAfter(cleanToday)) {
      final dateStr = _formatDate(cleanTarget);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are done for today! Next workout is on $dateStr.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (workoutData == null) {
      await db.togglePlanDayCompletion(dayData.id, true);
      ref.invalidate(planScheduleProvider(plan.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Today is a Rest Day! Marked as complete. Enjoy your break!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // Calculate End Date for the Projection UI
    final totalDaysInPlan = days.length;
    final projectedEndDate = activeStartDate.add(
      Duration(days: totalDaysInPlan - 1),
    );

    // Route to the new Countdown Screen!
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanCountdownScreen(
          workoutId: workoutData.id,
          workoutTitle: workoutData.title,
          planId: plan.id,
          planDayId: dayData.id,
          dayNumber: dayData.dayNumber,
          endDate: projectedEndDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planDetailsProvider(widget.planId));
    final scheduleAsync = ref.watch(planScheduleProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final plan = await ref
                  .read(databaseProvider)
                  .getPlan(widget.planId);
              final days = await ref
                  .read(databaseProvider)
                  .getPlanSchedule(widget.planId);

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
                await ref.read(databaseProvider).deletePlan(widget.planId);
                ref.invalidate(plansStreamProvider);
                if (context.mounted) Navigator.pop(context);
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

                      // --- PROGRESS BAR & LOGIC ---
                      scheduleAsync.when(
                        data: (days) {
                          if (days.isEmpty) return const SizedBox.shrink();

                          int completedCount = 0;
                          for (var row in days) {
                            if (row
                                .readTable(
                                  ref.read(databaseProvider).workoutPlanDays,
                                )
                                .isCompleted) {
                              completedCount++;
                            }
                          }

                          final progress = completedCount / days.length;
                          final isFullyCompleted = progress >= 1.0;
                          final alreadyArchived = plan.completedAt != null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Plan Progress',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress,
                                minHeight: 12,
                                borderRadius: BorderRadius.circular(6),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                              const SizedBox(height: 24),

                              // --- THE DYNAMIC START/RESUME/COMPLETE BUTTONS ---
                              if (alreadyArchived)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(40),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events,
                                        color: Colors.green,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Plan Conquered!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Text(
                                        'Completed on ${_formatDate(plan.completedAt!)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isFullyCompleted)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.emoji_events),
                                    label: const Text(
                                      'Claim Victory & Reset Plan',
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: Colors.orangeAccent,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () async {
                                      // FIX: Call the new method that logs AND resets!
                                      await ref
                                          .read(databaseProvider)
                                          .completePlanAndReset(plan.id);
                                      ref.invalidate(planDetailsProvider);
                                      ref.invalidate(planScheduleProvider);

                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '🎉 Plan Conquered & Logged! Ready for your next run.',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: FilledButton.icon(
                                        icon: Icon(
                                          plan.startDate == null
                                              ? Icons.play_arrow
                                              : Icons.replay,
                                        ),
                                        label: Text(
                                          plan.startDate == null
                                              ? 'Start Plan'
                                              : 'Resume Plan',
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                        onPressed: () =>
                                            _handlePlayPlan(plan, days),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Reset Progress?',
                                              ),
                                              content: const Text(
                                                'This will uncheck all days and stop tracking the calendar dates.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Reset'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && mounted) {
                                            await ref
                                                .read(databaseProvider)
                                                .resetPlanProgress(plan.id);
                                            ref.invalidate(planDetailsProvider);
                                            ref.invalidate(
                                              planScheduleProvider,
                                            );
                                          }
                                        },
                                        child: const Text('Reset'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 16),

                      // --- OPTIMIZE BUTTON ---
                      if (plan.completedAt ==
                          null) // Hide optimize if the plan is already finished!
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            icon: const Icon(
                              Icons.auto_awesome,
                              color: Colors.amber,
                            ),
                            label: const Text(
                              'Optimize Schedule based on Feedback',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.amber.withAlpha(30),
                              foregroundColor: Colors.amber,
                            ),
                            onPressed: _handleOptimizePlan,
                          ),
                        ),

                      const SizedBox(height: 32),
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
                      final isCompleted = dayData.isCompleted;

                      // --- CALCULATE THE DATE FOR UI DISPLAY ---
                      String dateLabel = '';
                      if (plan.startDate != null) {
                        final specificDate = plan.startDate!.add(
                          Duration(days: dayData.dayNumber - 1),
                        );
                        dateLabel = _formatDate(specificDate);
                      }

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
                            : isCompleted
                            ? Colors.green.withAlpha(20)
                            : null,
                        child: ListTile(
                          onTap: isRestDay
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WorkoutDetailScreen(
                                        workout: workoutData,
                                        planId:
                                            null, // Ensures it executes independently
                                        planDayId:
                                            null, // Ensures it does not auto-complete the plan
                                      ),
                                    ),
                                  );
                                },
                          leading: Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withAlpha(40)
                                  : isRestDay
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
                                color: isCompleted
                                    ? Colors.green
                                    : isRestDay
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
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dateLabel.isNotEmpty)
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    color: isCompleted
                                        ? Colors.green
                                        : Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              if (dayData.notes != null) Text(dayData.notes!),
                            ],
                          ),

                          trailing: Checkbox(
                            value: isCompleted,
                            activeColor: Colors.green,
                            onChanged: plan.completedAt != null
                                ? null
                                : (val) async {
                                    if (val != null) {
                                      await ref
                                          .read(databaseProvider)
                                          .togglePlanDayCompletion(
                                            dayData.id,
                                            val,
                                          );
                                      ref.invalidate(
                                        planScheduleProvider(widget.planId),
                                      );
                                    }
                                  },
                          ),
                        ),
                      );
                    }, childCount: days.length),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }
}
