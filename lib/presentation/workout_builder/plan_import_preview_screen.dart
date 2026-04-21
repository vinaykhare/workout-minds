import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/presentation/workout_builder/plan_details_screen.dart';
import 'package:workout_minds/presentation/workout_builder/workout_builder_screen.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';

class PlanImportPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> importData;

  const PlanImportPreviewScreen({super.key, required this.importData});

  @override
  ConsumerState<PlanImportPreviewScreen> createState() =>
      _PlanImportPreviewScreenState();
}

class _PlanImportPreviewScreenState
    extends ConsumerState<PlanImportPreviewScreen> {
  late Map<String, dynamic> _currentData;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.importData);
  }

  void _editPlanMetadata(AppLocalizations l10n) {
    final titleCtrl = TextEditingController(
      text: _currentData['plan']['title'] ?? '',
    );
    final descCtrl = TextEditingController(
      text: _currentData['plan']['description'] ?? '',
    );
    final goalCtrl = TextEditingController(
      text: _currentData['plan']['goal'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importEditDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.importEditNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: l10n.importEditDescLabel,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: goalCtrl,
                decoration: InputDecoration(
                  labelText: l10n.importEditGoalLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _currentData['plan']['title'] = titleCtrl.text.trim();
                _currentData['plan']['description'] = descCtrl.text.trim();
                _currentData['plan']['goal'] = goalCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n.importEditSaveBtn),
          ),
        ],
      ),
    );
  }

  void _editWorkout(String refKey, Map<String, dynamic> wData) {
    final exList = (wData['exercises'] as List<dynamic>).map((exData) {
      return DraftExercise(
        name: exData['name'],
        sets: exData['targetSets'] ?? 3,
        reps: exData['targetReps'] ?? 10,
        durationSeconds: exData['targetDurationSeconds'] ?? 30,
        isDuration: exData['targetDurationSeconds'] != null,
        restSecondsSet: exData['restSecondsAfterSet'] ?? 60,
        restSecondsExercise: exData['restSecondsAfterExercise'] ?? 90,
        imageUrl: exData['imageUrl'],
        localImagePath: exData['localImagePath'],
        equipment: exData['equipment'],
        targetWeight: exData['targetWeight'],
        instructions: exData['instructions'],
      );
    }).toList();

    ref.read(workoutDraftProvider.notifier).loadExercises(exList);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutBuilderScreen(
          existingTitle: wData['title'],
          onSaveDraft: (newTitle, newExercises) {
            setState(() {
              _currentData['workouts'][refKey]['title'] = newTitle;
              _currentData['workouts'][refKey]['exercises'] = newExercises
                  .map(
                    (e) => {
                      'name': e.name,
                      'muscleGroup': 'Custom',
                      'imageUrl': e.imageUrl,
                      'localImagePath': e.localImagePath,
                      'targetSets': e.sets,
                      'targetReps': e.isDuration ? null : e.reps,
                      'targetDurationSeconds': e.isDuration
                          ? e.durationSeconds
                          : null,
                      'restSecondsAfterSet': e.restSecondsSet,
                      'restSecondsAfterExercise': e.restSecondsExercise,
                      'equipment': e.equipment,
                      'targetWeight': e.targetWeight,
                      'instructions': e.instructions,
                    },
                  )
                  .toList();
            });
          },
        ),
      ),
    );
  }

  Future<void> _commitToDatabase(AppLocalizations l10n) async {
    setState(() => _isSaving = true);
    try {
      final planId = await ref
          .read(workoutShareProvider)
          .saveImportedPlanToDb(_currentData);

      if (mounted) {
        ref.invalidate(plansStreamProvider);
        ref.invalidate(workoutsStreamProvider);
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlanDetailsScreen(planId: planId)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.importFailed(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final planInfo = _currentData['plan'];
    final workoutsMap = _currentData['workouts'] as Map<String, dynamic>;
    final uniqueWorkouts = workoutsMap.entries.toList();

    // FIX: Removed leading underscores
    Widget buildLeftPanel() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.file_download_done,
            size: 80,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          Text(
            planInfo['title'] ?? l10n.importDefaultTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.importWeeksGoal(
              planInfo['totalWeeks'] ?? 4,
              planInfo['goal'] ?? 'General',
            ),
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _editPlanMetadata(l10n),
            icon: const Icon(Icons.edit, size: 16),
            label: Text(l10n.importEditBtn),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.importInstructions,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: _isSaving
                // FIX: Removed invalid 'const' keyword
                ? FilledButton.icon(
                    onPressed: null,
                    icon: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: Text('Saving...'),
                  )
                : FilledButton.icon(
                    onPressed: () => _commitToDatabase(l10n),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(
                      l10n.importSaveBtn,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ],
      );
    }

    Widget buildRightPanel() {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.importIncluded,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final refKey = uniqueWorkouts[index].key;
              final wData = uniqueWorkouts[index].value;
              final exCount = (wData['exercises'] as List).length;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha(100),
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.fitness_center, size: 20),
                  ),
                  title: Text(
                    wData['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(l10n.importExercisesCount(exCount)),
                  trailing: const Icon(
                    Icons.edit,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onTap: () => _editWorkout(refKey, wData),
                ),
              );
            }, childCount: uniqueWorkouts.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importReviewTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: buildLeftPanel(),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: buildRightPanel()),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.file_download_done,
                        size: 80,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        planInfo['title'] ?? l10n.importDefaultTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.importWeeksGoal(
                          planInfo['totalWeeks'] ?? 4,
                          planInfo['goal'] ?? 'General',
                        ),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _editPlanMetadata(l10n),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(l10n.importEditBtn),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.importInstructions,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.importIncluded,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final refKey = uniqueWorkouts[index].key;
                  final wData = uniqueWorkouts[index].value;
                  final exCount = (wData['exercises'] as List).length;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withAlpha(100),
                    elevation: 0,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.fitness_center, size: 20),
                      ),
                      title: Text(
                        wData['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(l10n.importExercisesCount(exCount)),
                      trailing: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onTap: () => _editWorkout(refKey, wData),
                    ),
                  );
                }, childCount: uniqueWorkouts.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: MediaQuery.of(context).size.width > 800
          ? null
          : (_isSaving
                ? FloatingActionButton.extended(
                    onPressed: null,
                    label: Text(l10n.importSaving),
                    icon: const CircularProgressIndicator(),
                  )
                : FloatingActionButton.extended(
                    onPressed: () => _commitToDatabase(l10n),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.check),
                    label: Text(
                      l10n.importSaveBtn,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )),
    );
  }
}
