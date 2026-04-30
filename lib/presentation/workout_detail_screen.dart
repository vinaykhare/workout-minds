import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';
import 'active_workout_screen.dart';

class WorkoutDetailScreen extends ConsumerStatefulWidget {
  final Workout workout;
  final int? planId;
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

  Future<void> _handleOptimizeWorkout(AppLocalizations l10n) async {
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
          .read(aiRepositoryProvider)
          .optimizeWorkout(widget.workout.id, profile);

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(workoutDetailsProvider(widget.workout.id));
        ref.invalidate(workoutsStreamProvider);
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
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- ACTIONS LOGIC ---
  Future<void> _handleEdit(List<drift.TypedResult> rows) async {
    final db = ref.read(databaseProvider);
    final planUsage = await (db.select(
      db.workoutPlanDays,
    )..where((t) => t.workoutId.equals(widget.workout.id))).get();
    final uniquePlanIds = planUsage.map((r) => r.planId).toSet().toList();

    List<WorkoutPlan> affectedPlans = [];
    if (uniquePlanIds.isNotEmpty) {
      affectedPlans = await (db.select(
        db.workoutPlans,
      )..where((t) => t.id.isIn(uniquePlanIds))).get();
    }

    if (affectedPlans.length > 1 && mounted) {
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
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, 'edit'),
              child: const Text('Edit Anyway'),
            ),
          ],
        ),
      );
      if (action != 'edit') return;
    }

    if (!mounted) return;

    // Load into builder
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
          existingWorkoutId: widget.workout.id,
          existingTitle: widget.workout.title,
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final db = ref.read(databaseProvider);
    final planUsage = await (db.select(
      db.workoutPlanDays,
    )..where((t) => t.workoutId.equals(widget.workout.id))).get();
    final uniquePlanIds = planUsage.map((r) => r.planId).toSet().toList();

    List<WorkoutPlan> affectedPlans = [];
    if (uniquePlanIds.isNotEmpty) {
      affectedPlans = await (db.select(
        db.workoutPlans,
      )..where((t) => t.id.isIn(uniquePlanIds))).get();
    }

    if (affectedPlans.isNotEmpty && mounted) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Workout in Use'),
            ],
          ),
          content: Text(
            'This workout is actively scheduled in ${affectedPlans.length} workout plan(s).\n\nDeleting it will permanently remove it from those plans.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Delete Anyway'),
            ),
          ],
        ),
      );
      if (action != 'delete') return;
    } else if (mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Workout?'),
          content: const Text(
            'This will permanently delete this workout. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await db.deleteWorkout(widget.workout.id);
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(workoutsStreamProvider);
    ref.invalidate(plansStreamProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout deleted.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _startWorkout(
    List<drift.TypedResult> rows,
    AppLocalizations l10n,
  ) async {
    final handler = ref.read(audioHandlerProvider);
    final pbState = handler.playbackState.value;
    final isPlayingSomething =
        pbState.processingState != AudioProcessingState.idle;

    if (isPlayingSomething && handler.currentWorkoutId != null) {
      final isSameWorkout = handler.currentWorkoutId == widget.workout.id;
      final activeTitle = handler.mediaItem.value?.album ?? 'Active Workout';

      final dialogTitle = isSameWorkout
          ? l10n.detailRestartTitle
          : l10n.detailEndActiveTitle;
      final dialogContent = isSameWorkout
          ? l10n.detailRestartContent(widget.workout.title)
          : l10n.detailEndActiveContent(activeTitle, widget.workout.title);
      final confirmBtnText = isSameWorkout
          ? l10n.detailRestart
          : l10n.detailEndAndStartBtn;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(confirmBtnText),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (rows.isEmpty) return;

    final db = ref.read(databaseProvider);
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
      widget.workout.title,
      widget.workout.id,
      appLocale,
      planId: widget.planId,
      planDayId: widget.planDayId,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildSummaryContent(
    List<drift.TypedResult> rows,
    AppLocalizations l10n,
  ) {
    final db = ref.read(databaseProvider);
    int totalSets = 0;
    double totalVolume = 0;
    Set<String> equipment = {};

    for (var row in rows) {
      final ex = row.readTable(db.exercises);
      final details = row.readTable(db.workoutExercises);

      totalSets += details.targetSets;
      if (ex.equipment != null && ex.equipment!.trim().isNotEmpty) {
        equipment.add(ex.equipment!.trim());
      }
      final weight = details.targetWeight ?? 0.0;
      final reps =
          details.targetReps ??
          1; // Default to 1 if time-based for volume mapping
      totalVolume += (weight * details.targetSets * reps);
    }

    final eqString = equipment.isEmpty ? 'None' : equipment.join(', ');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.detailStatExercises(rows.length),
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${rows.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.detailStatSets(totalSets),
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$totalSets',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.detailStatEquipment,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                eqString,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        if (totalVolume > 0) ...[
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.detailStatVolume,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${totalVolume.toInt()} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showSummaryModal(List<drift.TypedResult> rows, AppLocalizations l10n) {
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
            Text(
              l10n.detailSummaryTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildSummaryContent(rows, l10n),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    List<drift.TypedResult> rows,
    AppLocalizations l10n,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.edit),
          tooltip: l10n.detailActionEdit,
          onPressed: () => _handleEdit(rows),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.ios_share),
          tooltip: l10n.detailActionShare,
          onPressed: () async {
            final success = await ref
                .read(workoutShareProvider)
                .exportAndShare(widget.workout.id);
            if (!success && mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Export Failed')));
            }
          },
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.download),
          tooltip: l10n.detailActionDownload,
          onPressed: () async {
            final success = await ref
                .read(workoutShareProvider)
                .saveToDisk(widget.workout.id);
            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Workout saved to device!')),
              );
            }
          },
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          tooltip: l10n.detailActionDelete,
          style: IconButton.styleFrom(
            backgroundColor: Colors.redAccent.withAlpha(30),
          ),
          onPressed: _handleDelete,
        ),
      ],
    );
  }

  Widget _buildExerciseCard(
    drift.TypedResult row,
    bool isLast,
    AppLocalizations l10n,
  ) {
    final db = ref.read(databaseProvider);
    final ex = row.readTable(db.exercises);
    final details = row.readTable(db.workoutExercises);

    final isDuration = (details.targetDurationSeconds ?? 0) > 0;
    final restNext = details.restSecondsAfterExercise;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      ? Image.file(File(ex.localImagePath!), fit: BoxFit.cover)
                      : (ex.imageUrl != null && ex.imageUrl!.isNotEmpty)
                      ? Image.network(
                          ex.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(Icons.fitness_center, color: Colors.grey),
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
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDuration
                            ? '${details.targetSets} Sets x ${details.targetDurationSeconds}s'
                            : '${details.targetSets} Sets x ${details.targetReps} Reps',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((ex.equipment != null && ex.equipment!.isNotEmpty) ||
                          details.targetWeight != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            [
                              if (ex.equipment != null &&
                                  ex.equipment!.isNotEmpty)
                                ex.equipment,
                              if (details.targetWeight != null)
                                '${details.targetWeight} kg',
                            ].join('  •  '),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
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
                          // FIX: Wrapped in Expanded to prevent translation text overflow!
                          Expanded(
                            child: Text(
                              '${l10n.exRestSets} ${_formatTime(details.restSecondsAfterSet)}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                // FIX: Wrapped in Flexible to allow centering but prevent overflow
                Flexible(
                  child: Text(
                    l10n.detailRestNext(_formatTime(restNext)),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailsAsync = ref.watch(workoutDetailsProvider(widget.workout.id));
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.title),
        actions: [
          // PORTRAIT: Show the Pie Chart to open Summary Modal
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.pie_chart),
              onPressed: () {
                final rows = detailsAsync.value;
                if (rows != null && rows.isNotEmpty) {
                  _showSummaryModal(rows, l10n);
                }
              },
            ),
        ],
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(l10n.errorPrefix(err))),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(l10n.detailNoExercises),
              ),
            );
          }

          if (isWide) {
            // ==========================================
            // LANDSCAPE: MASTER-DETAIL DASHBOARD
            // ==========================================
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT PANEL: Controls & Stats
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.fitness_center,
                          size: 80,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.workout.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.workout.difficultyLevel,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // NEW: Action Buttons (Edit, Share, Download, Delete)
                        _buildActionButtons(rows, l10n),
                        const SizedBox(height: 32),

                        // Calculated Stats (Replaced with new summary builder)
                        Card(
                          elevation: 0,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withAlpha(100),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildSummaryContent(rows, l10n),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Optimize Button
                        FilledButton.tonalIcon(
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                          ),
                          label: Text(
                            l10n.detailOptimizeBtn,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(20),
                            backgroundColor: Colors.amber.withAlpha(30),
                            foregroundColor: Colors.amber,
                          ),
                          onPressed: () => _handleOptimizeWorkout(l10n),
                        ),
                        const SizedBox(height: 16),

                        // Start Button
                        StreamBuilder<PlaybackState>(
                          stream: ref.read(audioHandlerProvider).playbackState,
                          builder: (context, snapshot) {
                            final handler = ref.read(audioHandlerProvider);
                            final isPlayingSomething =
                                snapshot.data?.processingState !=
                                AudioProcessingState.idle;
                            final isActive =
                                isPlayingSomething &&
                                handler.currentWorkoutId == widget.workout.id;

                            if (isActive) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ActiveWorkoutScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(
                                      l10n.detailResume,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.all(20),
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _startWorkout(rows, l10n),
                                    icon: const Icon(Icons.restart_alt),
                                    label: Text(l10n.detailRestart),
                                  ),
                                ],
                              );
                            }

                            return FilledButton.icon(
                              onPressed: () => _startWorkout(rows, l10n),
                              icon: const Icon(Icons.play_arrow),
                              label: Text(
                                l10n.detailStart,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(20),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),

                // RIGHT PANEL: Exercise List
                Expanded(
                  flex: 2,
                  child: CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _buildExerciseCard(
                            rows[index],
                            index == rows.length - 1,
                            l10n,
                          );
                        }, childCount: rows.length),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
              ],
            );
          }

          // ==========================================
          // PORTRAIT: SCROLLING LIST
          // ==========================================
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Start Workout Button at the very top
                      StreamBuilder<PlaybackState>(
                        stream: ref.read(audioHandlerProvider).playbackState,
                        builder: (context, snapshot) {
                          final handler = ref.read(audioHandlerProvider);
                          final isPlayingSomething =
                              snapshot.data?.processingState !=
                              AudioProcessingState.idle;
                          final isActive =
                              isPlayingSomething &&
                              handler.currentWorkoutId == widget.workout.id;

                          if (isActive) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ActiveWorkoutScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(
                                    l10n.detailResume,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _startWorkout(rows, l10n),
                                  icon: const Icon(Icons.restart_alt),
                                  label: Text(l10n.detailRestart),
                                ),
                              ],
                            );
                          }

                          return FilledButton.icon(
                            onPressed: () => _startWorkout(rows, l10n),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              l10n.detailStart,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // The 4 action buttons
                      _buildActionButtons(rows, l10n),
                      const SizedBox(height: 16),

                      // The AI Optimize button
                      FilledButton.tonalIcon(
                        icon: const Icon(
                          Icons.auto_awesome,
                          color: Colors.amber,
                        ),
                        label: Text(
                          l10n.detailOptimizeBtn,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.amber.withAlpha(30),
                          foregroundColor: Colors.amber,
                        ),
                        onPressed: () => _handleOptimizeWorkout(l10n),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildExerciseCard(
                    rows[index],
                    index == rows.length - 1,
                    l10n,
                  );
                }, childCount: rows.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}
