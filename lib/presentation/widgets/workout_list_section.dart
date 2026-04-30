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
import 'package:workout_minds/presentation/workout_builder/plan_details_screen.dart'; // <--- NEW IMPORT
import 'package:workout_minds/core/l10n/app_localizations.dart';

class WorkoutListSection extends ConsumerWidget {
  const WorkoutListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workoutsAsync = ref.watch(filteredWorkoutsStreamProvider);
    return workoutsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, st) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(child: Text('Error: $e')),
        ),
      ),
      data: (List<Workout> workouts) {
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Individual Workouts',
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
                    isPlayingSomething &&
                    handler.currentWorkoutId == workout.id;

                return Card(
                  // Add a green border if it's the active workout
                  shape: isActive
                      ? RoundedRectangleBorder(
                          side: BorderSide(
                            color: Colors.green.shade500,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      if (isActive) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ActiveWorkoutScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WorkoutDetailScreen(workout: workout),
                          ),
                        );
                      }
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
                              final db = ref.read(databaseProvider);

                              final planUsage =
                                  await (db.select(db.workoutPlanDays)..where(
                                        (t) => t.workoutId.equals(workout.id),
                                      ))
                                      .get();
                              final uniquePlanIds = planUsage
                                  .map((r) => r.planId)
                                  .toSet()
                                  .toList();

                              bool confirmDelete = false;
                              List<WorkoutPlan> affectedPlans = [];

                              // --- FIX: Verify the plans actually exist and aren't ghosts! ---
                              if (uniquePlanIds.isNotEmpty) {
                                affectedPlans =
                                    await (db.select(db.workoutPlans)..where(
                                          (t) => t.id.isIn(uniquePlanIds),
                                        ))
                                        .get();
                              }

                              if (affectedPlans.isNotEmpty) {
                                final affectedPlans =
                                    await (db.select(db.workoutPlans)..where(
                                          (t) => t.id.isIn(uniquePlanIds),
                                        ))
                                        .get();

                                if (!context.mounted) return;

                                final action = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.redAccent,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Workout in Use'),
                                      ],
                                    ),
                                    content: Text(
                                      'This workout is actively scheduled in ${affectedPlans.length} workout plan(s).\n\nDeleting it will permanently remove it from those plans (turning those scheduled days into Rest Days).',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, 'cancel'),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, 'view'),
                                        child: const Text(
                                          'View Plans',
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, 'delete'),
                                        child: const Text('Delete Anyway'),
                                      ),
                                    ],
                                  ),
                                );

                                if (action == 'view') {
                                  if (!context.mounted) return;
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    builder: (ctx) => Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            'Plans Using This Workout',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ...affectedPlans.map(
                                            (plan) => Card(
                                              elevation: 0,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withAlpha(100),
                                              child: ListTile(
                                                leading: const Icon(
                                                  Icons.calendar_month,
                                                  color: Colors.green,
                                                ),
                                                title: Text(
                                                  plan.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  '${plan.totalWeeks} Weeks',
                                                ),
                                                trailing: const Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                onTap: () {
                                                  Navigator.pop(ctx);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          PlanDetailsScreen(
                                                            planId: plan.id,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                        ],
                                      ),
                                    ),
                                  );
                                  return; // Stop deletion flow
                                }

                                if (action == 'delete') {
                                  confirmDelete = true;
                                }
                              } else {
                                // 3. Standard delete confirmation for un-shared workouts
                                if (!context.mounted) return;
                                final standardConfirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Workout?'),
                                    content: Text(
                                      l10n.warningWorkoutDeletion,
                                      //'This will permanently delete this workout and all its historical execution logs. This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (standardConfirm == true) {
                                  confirmDelete = true;
                                }
                              }

                              // 4. Actually execute the deletion if confirmed
                              // 4. Actually execute the deletion if confirmed
                              if (confirmDelete) {
                                await db.deleteWorkout(workout.id);

                                // --- FIX: Aggressively wipe the Riverpod cache for everything! ---
                                ref.invalidate(dashboardControllerProvider);
                                ref.invalidate(plansStreamProvider);
                                ref.invalidate(planScheduleProvider);
                                ref.invalidate(planDetailsProvider);
                                // -----------------------------------------------------------------

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Workout deleted.'),
                                  ),
                                );
                              }
                            } else if (value == 'edit') {
                              _openEditorWithData(context, ref, workout);
                            } else if (value == 'share') {
                              final success = await ref
                                  .read(workoutShareProvider)
                                  .exportAndShare(workout.id);
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Export Failed'),
                                  ),
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
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
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
      },
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
        'equipment': ex.equipment,
        'targetWeight': details.targetWeight,
        'instructions': ex.instructions,
      };
    }).toList();

    final appLocale = ref.read(userProfileProvider).appLocale;
    handler.startWorkoutSequence(
      routine,
      targetWorkoutTitle,
      workoutId,
      appLocale,
      planId:
          null, // Optional: Because individual workouts don't belong to a plan
      planDayId: null, // Optional
    );

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

    // --- NEW: VALIDATION CHECK & VIEW PLANS ROUTING ---
    final planUsage = await (db.select(
      db.workoutPlanDays,
    )..where((t) => t.workoutId.equals(workout.id))).get();
    final uniquePlanIds = planUsage.map((r) => r.planId).toSet().toList();
    List<WorkoutPlan> affectedPlans = [];
    if (uniquePlanIds.isNotEmpty) {
      affectedPlans = await (db.select(
        db.workoutPlans,
      )..where((t) => t.id.isIn(uniquePlanIds))).get();
    }
    if (affectedPlans.length > 1) {
      final affectedPlans = await (db.select(
        db.workoutPlans,
      )..where((t) => t.id.isIn(uniquePlanIds))).get();

      if (!context.mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Shared Workout'),
            ],
          ),
          content: Text(
            'This workout is actively used in ${affectedPlans.length} different workout plans.\n\nEditing it here will permanently change the routine for ALL of those plans.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'view'),
              child: const Text(
                'View Plans',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, 'edit'),
              child: const Text('Edit Anyway'),
            ),
          ],
        ),
      );

      if (action == 'cancel' || action == null) return; // Stop if cancelled

      if (action == 'view') {
        if (!context.mounted) return;
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Plans Using This Workout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...affectedPlans.map(
                  (plan) => Card(
                    elevation: 0,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withAlpha(100),
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Colors.green,
                      ),
                      title: Text(
                        plan.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${plan.totalWeeks} Weeks'),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.pop(ctx); // Close the bottom sheet
                        // Route directly to the Plan Details Screen!
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PlanDetailsScreen(planId: plan.id),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
        return; // Stop the edit flow because they chose to view plans
      }
      // If action == 'edit', it naturally falls through to the editor logic below!
    }
    // -------------------------------------------------

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
        equipment: ex.equipment,
        targetWeight: details.targetWeight,
        instructions: ex.instructions,
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
