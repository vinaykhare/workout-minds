import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';

class ManualPlanBuilderScreen extends ConsumerStatefulWidget {
  // NEW: Added constructor parameters to support Editing!
  final int? existingPlanId;
  final String? existingTitle;
  final int? existingWeeks;
  final Map<int, Workout>? existingSchedule;

  const ManualPlanBuilderScreen({
    super.key,
    this.existingPlanId,
    this.existingTitle,
    this.existingWeeks,
    this.existingSchedule,
  });

  @override
  ConsumerState<ManualPlanBuilderScreen> createState() =>
      _ManualPlanBuilderScreenState();
}

class _ManualPlanBuilderScreenState
    extends ConsumerState<ManualPlanBuilderScreen> {
  final TextEditingController _titleController = TextEditingController();
  int _selectedWeeks = 4;
  final Map<int, Workout> _schedule = {};

  @override
  void initState() {
    super.initState();
    // Load existing data if we are in Edit Mode
    _titleController.text = widget.existingTitle ?? '';
    if (widget.existingWeeks != null) _selectedWeeks = widget.existingWeeks!;
    if (widget.existingSchedule != null) {
      _schedule.addAll(widget.existingSchedule!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _savePlan() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan title.')),
      );
      return;
    }

    final Map<int, int> dbSchedule = {};
    _schedule.forEach(
      (dayNumber, workout) => dbSchedule[dayNumber] = workout.id,
    );

    try {
      // NEW: Branch logic for Edit vs Create
      if (widget.existingPlanId != null) {
        await ref
            .read(databaseProvider)
            .updateManualPlan(
              widget.existingPlanId!,
              title,
              _selectedWeeks,
              dbSchedule,
            );
      } else {
        await ref
            .read(databaseProvider)
            .createManualPlan(title, _selectedWeeks, dbSchedule);
      }

      if (mounted) {
        ref.invalidate(plansStreamProvider);
        ref.invalidate(planDetailsProvider); // Refresh details screen if open
        ref.invalidate(planScheduleProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving plan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openWorkoutPicker(int dayNumber) {
    String searchQuery = ''; // Local search state for the bottom sheet

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) => StatefulBuilder(
        // FIX A1: StatefulBuilder allows local rebuilds
        builder: (context, setSheetState) => Consumer(
          builder: (context, ref, child) {
            final workoutsAsync = ref.watch(workoutsStreamProvider);

            return Container(
              padding: const EdgeInsets.only(top: 16),
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assign Day $dayNumber',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                  ),

                  // FIX A1: The Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search workouts...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) {
                        setSheetState(() => searchQuery = val.toLowerCase());
                      },
                    ),
                  ),
                  const Divider(),

                  // REST DAY OPTION
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.bedtime, color: Colors.white),
                    ),
                    title: const Text(
                      'Rest Day',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      setState(() => _schedule.remove(dayNumber));
                      Navigator.pop(bottomSheetContext);
                    },
                  ),
                  const Divider(),

                  // EXISTING WORKOUTS (Filtered)
                  Expanded(
                    child: workoutsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                      data: (workouts) {
                        // FIX A1: Apply the filter!
                        final filteredWorkouts = workouts
                            .where(
                              (w) =>
                                  w.title.toLowerCase().contains(searchQuery),
                            )
                            .toList();

                        if (filteredWorkouts.isEmpty) {
                          return const Center(
                            child: Text('No workouts found.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: filteredWorkouts.length,
                          itemBuilder: (context, index) {
                            final workout = filteredWorkouts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                child: const Icon(
                                  Icons.fitness_center,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                workout.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(workout.difficultyLevel),
                              onTap: () {
                                setState(() => _schedule[dayNumber] = workout);
                                Navigator.pop(bottomSheetContext);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // CREATE NEW WORKOUT BUTTON
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Workout'),
                      onPressed: () async {
                        ref
                            .read(workoutDraftProvider.notifier)
                            .loadExercises([]);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WorkoutBuilderScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = _selectedWeeks * 7;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Builder'),
        actions: [
          TextButton(
            onPressed: _savePlan,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // METADATA HEADER
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Plan Name',
                      border: OutlineInputBorder(),
                      hintText: 'E.g., 4-Week Shred',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedWeeks,
                        isExpanded: true,
                        // FIX: The missing list is added back here!
                        items: [1, 2, 4, 6, 8].map((w) {
                          return DropdownMenuItem(
                            value: w,
                            child: Text('$w Weeks'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedWeeks = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap a day to assign a workout:',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),

          // THE INTERACTIVE GRID
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    160, // The box will never be wider than 160px
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemCount: totalDays,
              itemBuilder: (context, index) {
                final dayNumber = index + 1;
                final workout = _schedule[dayNumber];
                final isRest = workout == null;

                return InkWell(
                  onTap: () => _openWorkoutPicker(dayNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRest
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(100)
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRest
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Day $dayNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRest
                                ? Colors.grey
                                : Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          isRest ? Icons.bedtime : Icons.fitness_center,
                          color: isRest
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            isRest ? 'Rest' : workout.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isRest
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              color: isRest ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
