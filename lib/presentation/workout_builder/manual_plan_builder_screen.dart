import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/providers.dart';

class ManualPlanBuilderScreen extends ConsumerStatefulWidget {
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
        ref.invalidate(planDetailsProvider);
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

  void _openWorkoutPicker(int dayNumber, AppLocalizations l10n) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Consumer(
          builder: (context, ref, child) {
            final workoutsAsync = ref.watch(workoutsStreamProvider);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                ), // Safe for tablets
                child: Container(
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
                              l10n.builderAssignDay(dayNumber),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  Navigator.pop(bottomSheetContext),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: l10n.searchWorkoutsHint,
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          onChanged: (val) {
                            setSheetState(
                              () => searchQuery = val.toLowerCase(),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.bedtime, color: Colors.white),
                        ),
                        title: Text(
                          l10n.planRestDay,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          setState(() => _schedule.remove(dayNumber));
                          Navigator.pop(bottomSheetContext);
                        },
                      ),
                      const Divider(),
                      Expanded(
                        child: workoutsAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Error: $e')),
                          data: (workouts) {
                            final filteredWorkouts = workouts
                                .where(
                                  (w) => w.title.toLowerCase().contains(
                                    searchQuery,
                                  ),
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
                                    setState(
                                      () => _schedule[dayNumber] = workout,
                                    );
                                    Navigator.pop(bottomSheetContext);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConfigPanel(AppLocalizations l10n) {
    // FIX: Dynamically ensure the current weeks value exists in the dropdown options!
    final List<int> weekOptions = [1, 2, 3, 4, 6, 8, 12];
    if (!weekOptions.contains(_selectedWeeks)) {
      weekOptions.add(_selectedWeeks);
      weekOptions.sort(); // Keep the list nicely ordered
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: l10n.builderPlanName,
            border: const OutlineInputBorder(),
            hintText: l10n.builderPlanNameHint,
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.builderPlanDuration,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedWeeks,
              isExpanded: true,
              items: weekOptions.map((w) {
                return DropdownMenuItem(
                  value: w,
                  child: Text(l10n.builderPlanWeeks(w)),
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
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.save),
          label: const Text(
            'Save Plan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          onPressed: _savePlan,
        ),
      ],
    );
  }

  Widget _buildGrid(int totalDays, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.builderPlanTapDay,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 64), // Safe scroll area
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
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
                onTap: () => _openWorkoutPicker(dayNumber, l10n),
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
                          isRest ? l10n.planRest : workout.title,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalDays = _selectedWeeks * 7;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.builderPlanTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          if (isWide) {
            // LANDSCAPE: 1:2 Split View
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: _buildConfigPanel(l10n),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: _buildGrid(totalDays, l10n),
                  ),
                ),
              ],
            );
          }

          // PORTRAIT: Stacked View
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildConfigPanel(l10n),
                const SizedBox(height: 32),
                Expanded(child: _buildGrid(totalDays, l10n)),
              ],
            ),
          );
        },
      ),
    );
  }
}
