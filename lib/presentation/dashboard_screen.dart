import 'dart:convert';
import 'package:workout_minds/presentation/widgets/volume_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/presentation/settings_screen.dart';
import 'package:workout_minds/presentation/active_workout_screen.dart';
import 'package:workout_minds/presentation/widgets/recent_workouts_section.dart';
import 'package:workout_minds/presentation/widgets/weekly_progress_card.dart';
import 'package:workout_minds/presentation/widgets/workout_list_section.dart';
import 'package:workout_minds/presentation/workout_builder/manual_plan_builder_screen.dart';
import 'package:workout_minds/presentation/workout_builder/plan_details_screen.dart';
import 'package:workout_minds/presentation/workout_builder/plan_import_preview_screen.dart';
import 'package:workout_minds/presentation/workout_builder/plan_log_summary_screen.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Widget _buildRecentPlanLogsSection(WidgetRef ref) {
    final planLogsAsync = ref.watch(recentPlanLogsProvider);

    return planLogsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverList(
          delegate: SliverChildListDelegate([
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Plan Trophies',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ...logs.map((data) {
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
              final start = data.log.startedAt;
              final end = data.log.completedAt;
              final dateString =
                  '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${end.year}';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: Colors.orangeAccent.withAlpha(20),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.orangeAccent.withAlpha(100)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PlanLogSummaryScreen(planLogData: data),
                      ),
                    );
                  },
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    child: Icon(Icons.emoji_events),
                  ),
                  title: Text(
                    data.plan.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    dateString,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            }),
          ]),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Removed workoutsAsync and currentSearchQuery! The dashboard no longer cares about search state.
    final l10n = AppLocalizations.of(context)!;
    final dashboardState = ref.watch(dashboardControllerProvider);

    // Listen for background errors and show a SnackBar!
    ref.listen(dashboardControllerProvider, (previous, next) {
      if (next is AsyncError) {
        final errorText = next.error.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // --- Listen for Pending File Imports ---
    ref.listen<Map<String, dynamic>?>(pendingImportProvider, (previous, next) {
      if (next != null) {
        Future.microtask(
          () => ref.read(pendingImportProvider.notifier).state = null,
        );

        final title = next['workout']['title'] ?? 'Imported Workout';
        final exercisesData = next['exercises'] as List<dynamic>;

        final draftExercises = exercisesData.map((exData) {
          return DraftExercise(
            name: exData['name'],
            sets: exData['targetSets'],
            reps: exData['targetReps'] ?? 10,
            durationSeconds: exData['targetDurationSeconds'] ?? 30,
            isDuration: exData['targetDurationSeconds'] != null,
            restSecondsSet: exData['restSecondsAfterSet'] ?? 60,
            restSecondsExercise: exData['restSecondsAfterExercise'] ?? 90,
            imageUrl: exData['imageUrl'],
          );
        }).toList();

        ref.read(workoutDraftProvider.notifier).loadExercises(draftExercises);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WorkoutBuilderScreen(existingTitle: "$title (Imported)"),
          ),
        );
      }
    });

    ref.listen<Map<String, dynamic>?>(pendingPlanImportProvider, (
      previous,
      next,
    ) async {
      if (next != null) {
        Future.microtask(
          () => ref.read(pendingPlanImportProvider.notifier).state = null,
        );

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => PlanImportPreviewScreen(importData: next),
            ),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            ref.invalidate(dashboardControllerProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dashboard Refreshed'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Image.asset("assets/images/app_logo.png", height: 40),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Build Manually',
            onSelected: (value) async {
              if (value == 'workout') {
                ref.read(workoutDraftProvider.notifier).loadExercises([]);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WorkoutBuilderScreen(),
                  ),
                );
                if (context.mounted) {
                  ref.invalidate(dashboardControllerProvider);
                }
              } else if (value == 'plan') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualPlanBuilderScreen(),
                  ),
                );
                if (context.mounted) {
                  ref.invalidate(dashboardControllerProvider);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'workout',
                child: Row(
                  children: [
                    Icon(Icons.fitness_center, size: 20),
                    SizedBox(width: 12),
                    Text('Build Workout'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'plan',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 20),
                    SizedBox(width: 12),
                    Text('Build Plan'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: l10n.aiGenerate,
            onPressed: () => _showAiGenerator(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import Workout',
            onPressed: () async {
              final workoutData = await ref
                  .read(workoutShareProvider)
                  .pickAndImportWorkout();

              if (workoutData != null && context.mounted) {
                if (workoutData['type'] == 'plan' ||
                    workoutData.containsKey('plan')) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) =>
                          PlanImportPreviewScreen(importData: workoutData),
                    ),
                  );
                } else {
                  final title =
                      workoutData['workout']['title'] ?? 'Imported Workout';
                  final exercisesData =
                      workoutData['exercises'] as List<dynamic>;

                  final draftExercises = exercisesData.map((exData) {
                    return DraftExercise(
                      name: exData['name'],
                      sets: exData['targetSets'],
                      reps: exData['targetReps'] ?? 10,
                      durationSeconds: exData['targetDurationSeconds'] ?? 30,
                      isDuration: exData['targetDurationSeconds'] != null,
                      restSecondsSet: exData['restSecondsAfterSet'] ?? 60,
                      restSecondsExercise:
                          exData['restSecondsAfterExercise'] ?? 90,
                      imageUrl: exData['imageUrl'],
                    );
                  }).toList();

                  ref
                      .read(workoutDraftProvider.notifier)
                      .loadExercises(draftExercises);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutBuilderScreen(
                        existingTitle: "$title (Imported)",
                      ),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings & Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              // --- LAYOUT ROUTING ---
              if (isWide) {
                // LANDSCAPE: Perfect 2-Column Split
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: CustomScrollView(
                        slivers: [
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: WeeklyProgressCard(),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: VolumeProgressCard(),
                            ),
                          ),
                          // FIX: Rendered directly because it returns a SliverList!
                          _buildRecentPlanLogsSection(ref),
                          const SliverToBoxAdapter(
                            child: RecentWorkoutsSection(),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 1,
                      child: CustomScrollView(
                        slivers: const [
                          SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverToBoxAdapter(child: _DashboardSearchBar()),
                          SliverToBoxAdapter(child: _PlansListSection()),
                          // FIX: Rendered directly because it returns a SliverList!
                          WorkoutListSection(),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // PORTRAIT LAYOUT
              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: WeeklyProgressCard(),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: VolumeProgressCard(),
                    ),
                  ),
                  // FIX: Rendered directly because it returns a SliverList!
                  _buildRecentPlanLogsSection(ref),
                  const SliverToBoxAdapter(child: RecentWorkoutsSection()),
                  const SliverToBoxAdapter(child: Divider(height: 32)),
                  const SliverToBoxAdapter(child: _DashboardSearchBar()),
                  const SliverToBoxAdapter(child: _PlansListSection()),
                  // FIX: Rendered directly because it returns a SliverList!
                  const WorkoutListSection(),
                ],
              );
            },
          ),
          if (dashboardState.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'AI is building your workout...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: StreamBuilder<PlaybackState>(
        stream: ref.read(audioHandlerProvider).playbackState,
        builder: (context, snapshot) {
          final state = snapshot.data;

          if (state != null &&
              state.processingState != AudioProcessingState.idle) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveWorkoutScreen(),
                  ),
                );
              },
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.fitness_center),
              label: const Text(
                'Resume Active Workout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showAiGenerator(BuildContext context, WidgetRef ref) {
    final TextEditingController promptController = TextEditingController();
    bool isGeneratingPlan = false; // Toggle state

    // 1. Grab the profile and localizations!
    final profile = ref.read(userProfileProvider);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false, // Don't let them dismiss while loading!
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.aiGeneratorTitle),
            content: isGeneratingPlan
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.generatingPlan, textAlign: TextAlign.center),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: promptController,
                        decoration: InputDecoration(
                          hintText: l10n.aiGeneratorHint,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // --- NEW: SMART CONTEXT FOOTER ---
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withAlpha(100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.tune,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${l10n.aiUsingProfile} ${profile.preferredStyle} • ${profile.goal}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.pop(dialogContext); // Close dialog
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                l10n.aiEditProfile,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ---------------------------------
                    ],
                  ),
            actions: isGeneratingPlan
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final prompt = promptController.text.trim();
                        if (prompt.isNotEmpty) {
                          ref
                              .read(dashboardControllerProvider.notifier)
                              .generateWorkout(prompt);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('1 Workout'),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Full Plan'),
                      onPressed: () async {
                        final prompt = promptController.text.trim();
                        if (prompt.isEmpty) return;

                        setState(() => isGeneratingPlan = true);

                        try {
                          // Call our Plan Repository
                          final planId = await ref
                              .read(aiPlanRepositoryProvider)
                              .generateAndSavePlan(prompt, profile);

                          // --- FIRE BACKGROUND SYNC AFTER PLAN GENERATION ---
                          if (profile.isAutoSyncEnabled) {
                            final profileJsonString = jsonEncode(
                              profile.toJson(),
                            );
                            ref
                                .read(driveSyncProvider)
                                .backupToCloud(profileJsonString)
                                .ignore();
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext); // Close dialog
                            Navigator.push(
                              dialogContext,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PlanDetailsScreen(planId: planId),
                              ),
                            );
                            ref.invalidate(dashboardControllerProvider);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setState(() => isGeneratingPlan = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
          );
        },
      ),
    );
  }
}

// --- FIX: ISOLATED SEARCH BAR ---
// Prevents the keyboard from closing and cursor from losing focus on every keystroke!
class _DashboardSearchBar extends ConsumerStatefulWidget {
  const _DashboardSearchBar();

  @override
  ConsumerState<_DashboardSearchBar> createState() =>
      _DashboardSearchBarState();
}

class _DashboardSearchBarState extends ConsumerState<_DashboardSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize with whatever is currently in Riverpod
    _controller = TextEditingController(
      text: ref.read(dashboardSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search plans & exercises...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha(100),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (val) {
          // Update Riverpod without rebuilding this specific widget!
          ref.read(dashboardSearchQueryProvider.notifier).state = val
              .toLowerCase();
        },
      ),
    );
  }
}

// --- FIX: ISOLATED PLANS LIST ---
// Fetches and filters its own data so it doesn't cause the parent screen to rebuild!
class _PlansListSection extends ConsumerWidget {
  const _PlansListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansStreamProvider);
    final currentSearchQuery = ref.watch(dashboardSearchQueryProvider);

    return plansAsync.when(
      data: (plans) {
        final filteredPlans = plans
            .where((p) => p.title.toLowerCase().contains(currentSearchQuery))
            .toList();

        if (filteredPlans.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'My Training Plans',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredPlans.length,
                itemBuilder: (context, index) {
                  final plan = filteredPlans[index];
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.all(4),
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PlanDetailsScreen(planId: plan.id),
                            ),
                          );
                          ref.invalidate(dashboardControllerProvider);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                plan.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${plan.totalWeeks} Weeks • ${plan.goal ?? "General"}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withAlpha(180),
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${plan.totalWeeks * 7} Days',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}
