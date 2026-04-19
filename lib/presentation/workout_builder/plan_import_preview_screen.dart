import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Clone the data so we can edit it in memory
    _currentData = Map<String, dynamic>.from(widget.importData);
  }

  // --- NEW: EDIT PLAN METADATA DIALOG ---
  void _editPlanMetadata() {
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
        title: const Text('Edit Plan Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plan Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: goalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Goal (e.g. Build Muscle)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
            child: const Text('Save Details'),
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
                      'localImagePath':
                          e.localImagePath, // Now properly caught!
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

  Future<void> _commitToDatabase() async {
    setState(() => _isSaving = true);
    try {
      final planId = await ref
          .read(workoutShareProvider)
          .saveImportedPlanToDb(_currentData);

      if (mounted) {
        ref.invalidate(plansStreamProvider);
        ref.invalidate(workoutsStreamProvider);

        Navigator.pop(context); // Close the preview screen
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
            content: Text('Failed to import: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planInfo = _currentData['plan'];
    final workoutsMap = _currentData['workouts'] as Map<String, dynamic>;
    final uniqueWorkouts = workoutsMap.entries.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Review Import')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.file_download_done,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    planInfo['title'] ?? 'Imported Plan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${planInfo['totalWeeks']} Weeks  •  ${planInfo['goal'] ?? 'General'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  // --- NEW: THE EDIT BUTTON ---
                  TextButton.icon(
                    onPressed: _editPlanMetadata,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Plan Details'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tap any workout below to preview or edit it before saving this plan to your device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Included Workouts',
                      style: TextStyle(
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
                  subtitle: Text('$exCount Exercises'),
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isSaving
          ? const FloatingActionButton.extended(
              onPressed: null,
              label: Text('Saving...'),
              icon: CircularProgressIndicator(),
            )
          : FloatingActionButton.extended(
              onPressed: _commitToDatabase,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.check),
              label: const Text(
                'Save Plan & Workouts',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}
