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
    // FIX 1: Watch the new filtered stream directly!
    final workoutsAsync = ref.watch(filteredWorkoutsStreamProvider);
    final l10n = AppLocalizations.of(context)!;
    final dashboardState = ref.watch(dashboardControllerProvider);
    // Also read the current search query
    final currentSearchQuery = ref.watch(dashboardSearchQueryProvider);

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

    // --- FIX 2: Listen for Pending File Imports ---
    ref.listen<Map<String, dynamic>?>(pendingImportProvider, (previous, next) {
      if (next != null) {
        // 1. Erase the pending file from state immediately so we don't open it twice!
        Future.microtask(
          () => ref.read(pendingImportProvider.notifier).state = null,
        );

        // 2. Parse the data
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

        // 3. Load into Riverpod
        ref.read(workoutDraftProvider.notifier).loadExercises(draftExercises);

        // 4. Safely Navigate!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WorkoutBuilderScreen(existingTitle: "$title (Imported)"),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        // 2. l10n used here
        title: GestureDetector(
          onTap: () {
            // Instantly re-fetches all workouts from the Drift database!
            ref.invalidate(dashboardControllerProvider);

            // Optional: Give the user a tiny visual confirmation
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
                // Refresh dashboard when returning
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
                // Refresh dashboard when returning
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
            // 3. l10n and _showAiGenerator used here
            tooltip: l10n.aiGenerate,
            onPressed: () => _showAiGenerator(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import Workout',
            onPressed: () async {
              // 1. Pick and Parse the file
              final workoutData = await ref
                  .read(workoutShareProvider)
                  .pickAndImportWorkout();

              if (workoutData != null && context.mounted) {
                final title =
                    workoutData['workout']['title'] ?? 'Imported Workout';
                final exercisesData = workoutData['exercises'] as List<dynamic>;

                // 2. Map into DraftExercises
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

                // 3. Load into Riverpod
                ref
                    .read(workoutDraftProvider.notifier)
                    .loadExercises(draftExercises);

                // 4. Push to Builder Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutBuilderScreen(
                      existingTitle: "$title (Imported)",
                    ),
                  ),
                );
              } else if (context.mounted) {
                // Optional: Show an error if they picked an invalid file
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid file or import canceled.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
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
          workoutsAsync.when(
            data: (workouts) => LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                Widget buildSearchBar() {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      // Pre-fill it just in case
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: currentSearchQuery,
                          selection: TextSelection.collapsed(
                            offset: currentSearchQuery.length,
                          ),
                        ),
                      ),
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
                      // Update the global state instantly when typing
                      onChanged: (val) =>
                          ref
                              .read(dashboardSearchQueryProvider.notifier)
                              .state = val
                              .toLowerCase(),
                    ),
                  );
                }

                Widget buildPlansSection() {
                  return Consumer(
                    builder: (context, ref, child) {
                      final plansAsync = ref.watch(plansStreamProvider);
                      return plansAsync.when(
                        data: (plans) {
                          // Apply the same global search filter to Plans
                          final filteredPlans = plans
                              .where(
                                (p) => p.title.toLowerCase().contains(
                                  currentSearchQuery,
                                ),
                              )
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
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height:
                                    160, // FIX 1: Increased height from 140 to 160
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  itemCount: plans.length,
                                  itemBuilder: (context, index) {
                                    final plan = plans[index];
                                    return Container(
                                      width: 280,
                                      margin: const EdgeInsets.all(4),
                                      child: Card(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PlanDetailsScreen(
                                                      planId: plan.id,
                                                    ),
                                              ),
                                            );
                                            ref.invalidate(
                                              dashboardControllerProvider,
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  plan.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                  maxLines:
                                                      2, // FIX 2: Restrict to 2 lines
                                                  overflow: TextOverflow
                                                      .ellipsis, // Add the '...' if it's too long
                                                ),
                                                const Spacer(), // Pushes the calendar icon to the bottom
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.calendar_month,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${plan.totalWeeks * 7} Days',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
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
                    },
                  );
                }

                // --- LAYOUT ROUTING ---
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: CustomScrollView(
                          slivers: [
                            const SliverToBoxAdapter(
                              child: WeeklyProgressCard(),
                            ),
                            _buildRecentPlanLogsSection(ref),
                            // Search Bar for wide screens
                            SliverToBoxAdapter(child: buildSearchBar()),
                            const SliverToBoxAdapter(
                              child: RecentWorkoutsSection(),
                            ),
                            SliverToBoxAdapter(child: buildPlansSection()),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: CustomScrollView(
                          slivers: [
                            // FIX: 'workouts' is already perfectly filtered by the stream!
                            WorkoutListSection(workouts: workouts),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // MOBILE LAYOUT
                return CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: WeeklyProgressCard()),
                    // Search Bar for mobile screens
                    _buildRecentPlanLogsSection(ref),
                    SliverToBoxAdapter(child: buildSearchBar()),
                    const SliverToBoxAdapter(child: RecentWorkoutsSection()),
                    SliverToBoxAdapter(child: buildPlansSection()),
                    // FIX: 'workouts' is already perfectly filtered by the stream!
                    WorkoutListSection(workouts: workouts),
                  ],
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          l10n.errorPrefix("AI Generation Failed"),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Dismiss & Go Back'),
                      onPressed: () =>
                          ref.invalidate(dashboardControllerProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 5. dashboardState used here
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
      // 6. The Dynamic Active Workout Button!
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

    showDialog(
      context: context,
      barrierDismissible: false, // Don't let them dismiss while loading!
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('AI Personal Trainer'),
            content: isGeneratingPlan
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Designing your custom program...\nThis usually takes 10-15 seconds.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: promptController,
                        decoration: const InputDecoration(
                          hintText:
                              "E.g., '4-week six-pack routine' or 'Leg day focus'",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
            actions: isGeneratingPlan
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    // Option A: Single Workout
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
                    // Option B: Multi-Week Plan!
                    FilledButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Full Plan'),
                      onPressed: () async {
                        final prompt = promptController.text.trim();
                        if (prompt.isEmpty) return;

                        setState(() => isGeneratingPlan = true);

                        try {
                          final profile = ref.read(userProfileProvider);
                          // Call our new AI Plan Repository
                          final planId = await ref
                              .read(aiPlanRepositoryProvider)
                              .generateAndSavePlan(prompt, profile);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext); // Close dialog
                            // Push the Plan Details Screen!
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
