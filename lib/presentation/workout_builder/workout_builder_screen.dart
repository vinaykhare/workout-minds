import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' as drift;
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkoutBuilderScreen extends ConsumerStatefulWidget {
  final int? existingWorkoutId;
  final String? existingTitle; // FIX 5: Add this variable

  const WorkoutBuilderScreen({
    super.key,
    this.existingWorkoutId,
    this.existingTitle,
  });

  @override
  ConsumerState<WorkoutBuilderScreen> createState() =>
      _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends ConsumerState<WorkoutBuilderScreen> {
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // FIX 6: Use the existing title if editing, otherwise default
    _titleController.text = widget.existingTitle ?? "My Custom Workout";
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _removeWithUndo(
    BuildContext context,
    int index,
    DraftExercise ex,
    WorkoutDraftNotifier notifier,
  ) {
    notifier.removeExercise(index);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ex.name} removed'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => notifier.insertExercise(index, ex),
        ),
      ),
    );
  }

  // DIALOG 1: Title Only
  Future<void> _showTitleDialog(
    BuildContext context,
    int index,
    DraftExercise ex,
    WorkoutDraftNotifier notifier,
  ) async {
    final nameController = TextEditingController(text: ex.name);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Exercise'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Exercise Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                notifier.updateExercise(
                  index,
                  ex.copyWith(name: nameController.text.trim()),
                );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // DIALOG 2: Image Source Only
  Future<void> _showImageDialog(
    BuildContext context,
    int index,
    DraftExercise ex,
    WorkoutDraftNotifier notifier,
  ) async {
    final urlController = TextEditingController(text: ex.imageUrl ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exercise Image'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- OPTION A: INTERNET SOURCES ---
              const Text(
                'From the Web',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'Image/GIF URL',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () {
                      if (urlController.text.isNotEmpty) {
                        notifier.updateExercise(
                          index,
                          ex.copyWith(
                            imageUrl: urlController.text,
                            clearLocalImage: true,
                          ),
                        );
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.search),
                label: const Text('Search Web for Image/GIF'),
                onPressed: () async {
                  // Creates a search query like: "Bench Press exercise gif"
                  final query = Uri.encodeComponent('${ex.name} exercise gif');
                  final url = Uri.parse(
                    'https://www.google.com/search?tbm=isch&q=$query',
                  );

                  try {
                    // Launches the phone's native web browser
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open web browser.'),
                        ),
                      );
                    }
                  }
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  '— OR —',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),

              // --- OPTION B: LOCAL DEVICE ---
              const Text(
                'From this Device',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick from Device Gallery'),
                onPressed: () async {
                  try {
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null && dialogContext.mounted) {
                      notifier.updateExercise(
                        index,
                        ex.copyWith(
                          localImagePath: image.path,
                          clearImageUrl: true,
                        ),
                      );
                      Navigator.pop(dialogContext);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to pick image.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // THE DRIFT DATABASE SAVE LOGIC
  // THE CORRECTED DRIFT DATABASE SAVE LOGIC
  Future<void> _saveWorkout(List<DraftExercise> draftExercises) async {
    if (draftExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final title = _titleController.text.trim().isEmpty
        ? "My Custom Workout"
        : _titleController.text.trim();

    try {
      await db.transaction(() async {
        int workoutId;

        if (widget.existingWorkoutId != null) {
          // --- EDIT MODE ---
          workoutId = widget.existingWorkoutId!;
          await (db.update(
            db.workouts,
          )..where((t) => t.id.equals(workoutId))).write(
            WorkoutsCompanion(
              title: drift.Value(title),
            ), // Removed drift. prefix
          );
          await (db.delete(
            db.workoutExercises,
          )..where((t) => t.workoutId.equals(workoutId))).go();
        } else {
          // --- CREATE MODE ---
          workoutId = await db
              .into(db.workouts)
              .insert(
                WorkoutsCompanion.insert(
                  // Removed drift. prefix
                  title: title,
                  difficultyLevel: 'Custom',
                  aiGenerated: const drift.Value(false),
                ),
              );
        }

        for (int i = 0; i < draftExercises.length; i++) {
          final draftEx = draftExercises[i];
          int exerciseId;

          final existingEx = await (db.select(
            db.exercises,
          )..where((t) => t.name.equals(draftEx.name))).getSingleOrNull();

          if (existingEx != null) {
            exerciseId = existingEx.id;
            // Simply pass the current values. If they are null, Drift gracefully writes null.
            await (db.update(
              db.exercises,
            )..where((t) => t.id.equals(exerciseId))).write(
              ExercisesCompanion(
                // Removed drift. prefix
                imageUrl: drift.Value(draftEx.imageUrl),
                localImagePath: drift.Value(draftEx.localImagePath),
              ),
            );
          } else {
            exerciseId = await db
                .into(db.exercises)
                .insert(
                  ExercisesCompanion.insert(
                    // Removed drift. prefix
                    name: draftEx.name,
                    muscleGroup: 'Custom',
                    isCustom: const drift.Value(true),
                    imageUrl: drift.Value(draftEx.imageUrl),
                    localImagePath: drift.Value(draftEx.localImagePath),
                  ),
                );
          }

          await db
              .into(db.workoutExercises)
              .insert(
                WorkoutExercisesCompanion.insert(
                  // The clean insert is back!
                  workoutId: workoutId,
                  exerciseId: exerciseId,
                  orderIndex: i,
                  targetSets: draftEx.sets,
                  targetReps: draftEx.isDuration
                      ? const drift.Value(null)
                      : drift.Value(draftEx.reps),
                  targetDurationSeconds: draftEx.isDuration
                      ? drift.Value(draftEx.durationSeconds)
                      : const drift.Value(null),
                  restSecondsAfterSet: draftEx.restSecondsSet,
                  restSecondsAfterExercise: draftEx.restSecondsExercise,
                ),
              );
        }
      });

      if (!mounted) return;

      ref.invalidate(dashboardControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout Saved Successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftExercises = ref.watch(workoutDraftProvider);
    final notifier = ref.read(workoutDraftProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () =>
                _saveWorkout(draftExercises), // Triggers the DB transaction
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Workout Name',
                border: OutlineInputBorder(),
                filled: true,
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: draftExercises.isEmpty
                ? const Center(child: Text('Tap + to add your first exercise'))
                : ReorderableListView.builder(
                    itemCount: draftExercises.length,
                    onReorder: (oldIndex, newIndex) =>
                        notifier.reorder(oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final ex = draftExercises[index];
                      return Card(
                        key: ValueKey('exercise_${ex.name}_$index'),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          // Image Click -> Show Image Dialog
                          leading: InkWell(
                            onTap: () =>
                                _showImageDialog(context, index, ex, notifier),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: ex.localImagePath != null
                                  ? Image.file(
                                      File(ex.localImagePath!),
                                      fit: BoxFit.cover,
                                    )
                                  : (ex.imageUrl != null &&
                                        ex.imageUrl!.isNotEmpty)
                                  ? Image.network(
                                      ex.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          const Icon(
                                            Icons.broken_image,
                                            color: Colors.red,
                                          ),
                                    )
                                  : const Icon(
                                      Icons.add_a_photo,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          title: Row(
                            children: [
                              // Title Click -> Show Title Dialog
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showTitleDialog(
                                    context,
                                    index,
                                    ex,
                                    notifier,
                                  ),
                                  child: Text(
                                    ex.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removeWithUndo(
                                  context,
                                  index,
                                  ex,
                                  notifier,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('${ex.sets} Sets x ${ex.reps} Reps'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  _NumberInputRow(
                                    label: 'Sets:',
                                    value: ex.sets,
                                    onChanged: (val) => notifier.updateExercise(
                                      index,
                                      ex.copyWith(sets: val),
                                    ),
                                  ),

                                  _DurationInputRow(
                                    label: 'Rest Between Sets:',
                                    totalSeconds: ex.restSecondsSet,
                                    onChanged: (val) => notifier.updateExercise(
                                      index,
                                      ex.copyWith(restSecondsSet: val),
                                    ),
                                  ),
                                  SwitchListTile(
                                    title: const Text(
                                      'Time-based Exercise (e.g. Planks)',
                                    ),
                                    value: ex.isDuration,
                                    onChanged: (val) => notifier.updateExercise(
                                      index,
                                      ex.copyWith(isDuration: val),
                                    ),
                                  ),
                                  if (!ex.isDuration)
                                    _NumberInputRow(
                                      label: 'Reps:',
                                      value: ex.reps,
                                      onChanged: (val) =>
                                          notifier.updateExercise(
                                            index,
                                            ex.copyWith(reps: val),
                                          ),
                                    )
                                  else
                                    _DurationInputRow(
                                      label: 'Duration:',
                                      totalSeconds: ex.durationSeconds ?? 30,
                                      onChanged: (val) =>
                                          notifier.updateExercise(
                                            index,
                                            ex.copyWith(durationSeconds: val),
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha(128),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: _DurationInputRow(
                                label: 'Rest Before Next Exercise:',
                                totalSeconds: ex.restSecondsExercise,
                                onChanged: (val) => notifier.updateExercise(
                                  index,
                                  ex.copyWith(restSecondsExercise: val),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // FIX: Uses the current list length to auto-increment the name
          notifier.addExercise(
            DraftExercise(name: "Exercise ${draftExercises.length + 1}"),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
    );
  }
}

// NOTE: Keep your _NumberInputRow and _DurationInputRow classes down here!
// I've omitted them here for brevity, but they stay exactly the same.

class _NumberInputRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumberInputRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => onChanged((value - 1).clamp(1, 999)),
          ),
          SizedBox(
            width: 50, // Fixed width prevents jittering
            child: TextFormField(
              key: ValueKey(value.toString()), // Syncs with the +/- buttons
              initialValue: value.toString().padLeft(2, '0'),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null) {
                  onChanged(parsed.clamp(1, 999));
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

// NEW: Splits raw seconds into Minutes and Seconds for the UI
class _DurationInputRow extends StatelessWidget {
  final String label;
  final int totalSeconds;
  final ValueChanged<int> onChanged;

  const _DurationInputRow({
    required this.label,
    required this.totalSeconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int mins = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),

          // Minutes
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => onChanged(((mins - 1).clamp(0, 59) * 60) + secs),
          ),
          Text(
            '${mins.toString().padLeft(2, '0')}m',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(((mins + 1).clamp(0, 59) * 60) + secs),
          ),

          const SizedBox(width: 8),

          // Seconds
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => onChanged((mins * 60) + (secs - 5).clamp(0, 55)),
          ),
          Text(
            '${secs.toString().padLeft(2, '0')}s',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged((mins * 60) + (secs + 5).clamp(0, 59)),
          ),
        ],
      ),
    );
  }
}
