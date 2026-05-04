import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
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

  Future<void> _handleOptimizePlan(AppLocalizations l10n) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              l10n.detailOptimizingMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
          SnackBar(
            content: Text(l10n.detailOptimizeSuccess),
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

  void _handlePlayPlan(
    WorkoutPlan plan,
    List<dynamic> days,
    AppLocalizations l10n,
  ) async {
    final handler = ref.read(audioHandlerProvider);
    final pbState = handler.playbackState.value;
    final isPlayingSomething =
        pbState.processingState != AudioProcessingState.idle;

    if (isPlayingSomething && handler.currentWorkoutId != null) {
      final activeTitle = handler.mediaItem.value?.album ?? 'Active Workout';

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.detailEndActiveTitle),
          content: Text(l10n.detailEndActiveContent(activeTitle, plan.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(l10n.detailEndAndStartBtn),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final db = ref.read(databaseProvider);
    var nextUndoneRow = days
        .where((r) => !r.readTable(db.workoutPlanDays).isCompleted)
        .firstOrNull;

    if (nextUndoneRow == null) return;

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
      if (!mounted) return;
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

    final projectedEndDate = activeStartDate.add(
      Duration(days: days.length - 1),
    );

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

  Widget _buildActionButtons(
    WorkoutPlan plan,
    List<dynamic> days,
    AppLocalizations l10n,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.edit),
          tooltip: l10n.planActionEdit,
          onPressed: () async {
            Map<int, Workout> currentSchedule = {};
            final db = ref.read(databaseProvider);
            for (var row in days) {
              final dayData = row.readTable(db.workoutPlanDays);
              final workoutData = row.readTableOrNull(db.workouts);
              if (workoutData != null) {
                currentSchedule[dayData.dayNumber] = workoutData;
              }
            }
            if (!mounted) return;
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
        IconButton.filledTonal(
          icon: const Icon(Icons.ios_share),
          tooltip: l10n.planActionShare,
          onPressed: () async {
            final success = await ref
                .read(workoutShareProvider)
                .exportAndSharePlan(widget.planId);
            if (!success && mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Export Failed')));
            }
          },
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.download),
          tooltip: l10n.planActionDownload,
          onPressed: () async {
            final success = await ref
                .read(workoutShareProvider)
                .savePlanToDisk(widget.planId);
            if (success && mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Plan saved!')));
            }
          },
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          tooltip: l10n.planActionDelete,
          style: IconButton.styleFrom(
            backgroundColor: Colors.redAccent.withAlpha(30),
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.planDeleteTitle),
                content: Text(l10n.planDeleteContent),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.planActionDelete),
                  ),
                ],
              ),
            );

            if (confirm == true && mounted) {
              await ref.read(databaseProvider).deletePlan(widget.planId);
              ref.invalidate(plansStreamProvider);
              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    WorkoutPlan plan,
    List<dynamic> days,
    AppLocalizations l10n,
  ) {
    if (days.isEmpty) return const SizedBox.shrink();

    int completedCount = 0;
    final db = ref.read(databaseProvider);
    for (var row in days) {
      if (row.readTable(db.workoutPlanDays).isCompleted) {
        completedCount++;
      }
    }

    final progress = completedCount / days.length;
    final isFullyCompleted = progress >= 1.0;
    final alreadyArchived = plan.completedAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.planProgress,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
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

        if (alreadyArchived)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, color: Colors.green, size: 48),
                const SizedBox(height: 8),
                Text(
                  l10n.planConquered,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  l10n.planCompletedOn(_formatDate(plan.completedAt!)),
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          )
        else if (isFullyCompleted)
          FilledButton.icon(
            icon: const Icon(Icons.emoji_events),
            label: Text(l10n.planClaimVictory),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              await ref.read(databaseProvider).completePlanAndReset(plan.id);
              ref.invalidate(planDetailsProvider);
              ref.invalidate(planScheduleProvider);
            },
          )
        else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: Icon(
                    plan.startDate == null ? Icons.play_arrow : Icons.replay,
                  ),
                  label: Text(
                    plan.startDate == null ? l10n.planStart : l10n.planResume,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () => _handlePlayPlan(plan, days, l10n),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.planResetTitle),
                        content: Text(l10n.planResetContent),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.planResetBtn),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await ref
                          .read(databaseProvider)
                          .resetPlanProgress(plan.id);
                      ref.invalidate(planDetailsProvider);
                      ref.invalidate(planScheduleProvider);
                    }
                  },
                  child: Text(l10n.planResetBtn),
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final planAsync = ref.watch(planDetailsProvider(widget.planId));
    final scheduleAsync = ref.watch(planScheduleProvider(widget.planId));
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading plan: $e')),
        data: (plan) {
          return scheduleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (days) {
              if (isWide) {
                // ==========================================
                // LANDSCAPE: MASTER-DETAIL SPLIT
                // ==========================================
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              size: 80,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              plan.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              plan.description ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 32),
                            _buildActionButtons(plan, days, l10n),
                            const SizedBox(height: 32),
                            Card(
                              elevation: 0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha(100),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: _buildProgressCard(plan, days, l10n),
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (plan.completedAt == null)
                              FilledButton.tonalIcon(
                                icon: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.amber,
                                ),
                                label: Text(
                                  l10n.planOptimizeBtn,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.all(20),
                                  backgroundColor: Colors.amber.withAlpha(30),
                                  foregroundColor: Colors.amber,
                                ),
                                onPressed: () => _handleOptimizePlan(l10n),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                              child: Text(
                                l10n.planSchedule,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          _buildScheduleList(days, plan, l10n),
                          const SliverToBoxAdapter(child: SizedBox(height: 60)),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // ==========================================
              // PORTRAIT: LINEAR SCROLL
              // ==========================================
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          const SizedBox(height: 24),
                          _buildProgressCard(plan, days, l10n),
                          const SizedBox(height: 24),
                          _buildActionButtons(plan, days, l10n),
                          const SizedBox(height: 24),
                          if (plan.completedAt == null)
                            FilledButton.tonalIcon(
                              icon: const Icon(
                                Icons.auto_awesome,
                                color: Colors.amber,
                              ),
                              label: Text(
                                l10n.planOptimizeBtn,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.amber.withAlpha(30),
                                foregroundColor: Colors.amber,
                              ),
                              onPressed: () => _handleOptimizePlan(l10n),
                            ),
                          const SizedBox(height: 32),
                          Text(
                            l10n.planSchedule,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildScheduleList(days, plan, l10n),
                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScheduleList(
    List<dynamic> days,
    WorkoutPlan plan,
    AppLocalizations l10n,
  ) {
    final db = ref.read(databaseProvider);
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final row = days[index];
        final dayData = row.readTable(db.workoutPlanDays);
        final workoutData = row.readTableOrNull(db.workouts);

        final isRestDay = workoutData == null;
        final isCompleted = dayData.isCompleted;

        String dateLabel = '';
        if (plan.startDate != null) {
          final specificDate = plan.startDate!.add(
            Duration(days: dayData.dayNumber - 1),
          );
          dateLabel = _formatDate(specificDate);
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: isRestDay
              ? Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha(100)
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
                          planId: null,
                          planDayId: null,
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
                    : Theme.of(context).colorScheme.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.planDayLabel(dayData.dayNumber),
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
              isRestDay ? l10n.planRestDay : workoutData.title,
              style: TextStyle(
                fontWeight: isRestDay ? FontWeight.normal : FontWeight.bold,
                color: isRestDay ? Colors.grey : null,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
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
                          : Theme.of(context).colorScheme.secondary,
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
                            .togglePlanDayCompletion(dayData.id, val);
                        ref.invalidate(planScheduleProvider(widget.planId));
                      }
                    },
            ),
          ),
        );
      }, childCount: days.length),
    );
  }
}
