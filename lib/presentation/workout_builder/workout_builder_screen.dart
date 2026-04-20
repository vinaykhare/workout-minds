import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' as drift;
import 'package:workout_minds/core/l10n/app_localizations.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/presentation/dashboard_controller.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/repositories/providers.dart';
import 'package:workout_minds/repositories/workout_builder/workout_builder_provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum DetailType { exercise, rest }

class WorkoutBuilderScreen extends ConsumerStatefulWidget {
  final int? existingWorkoutId;
  final String? existingTitle;
  final void Function(String title, List<DraftExercise> exercises)? onSaveDraft;

  const WorkoutBuilderScreen({
    super.key,
    this.existingWorkoutId,
    this.existingTitle,
    this.onSaveDraft,
  });

  @override
  ConsumerState<WorkoutBuilderScreen> createState() =>
      _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends ConsumerState<WorkoutBuilderScreen> {
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Tracks the currently selected item for the Landscape detail view
  int _selectedDetailIndex = 0;
  DetailType _selectedDetailType = DetailType.exercise;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.existingTitle ?? "My Custom Workout";
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final int mins = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
    if (mins > 0) return '${mins}m';
    return '${secs}s';
  }

  void _removeWithUndo(
    BuildContext context,
    int index,
    DraftExercise ex,
    WorkoutDraftNotifier notifier,
  ) {
    notifier.removeExercise(index);
    final currentExercises = ref.read(workoutDraftProvider);

    // Clamp the selected index if we deleted the currently viewed item in landscape
    if (_selectedDetailIndex >= currentExercises.length) {
      setState(() {
        _selectedDetailIndex = math.max(0, currentExercises.length - 1);
        _selectedDetailType = DetailType.exercise;
      });
    }

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

  Future<void> _showTitleDialog(
    BuildContext context,
    int index,
    DraftExercise ex,
    WorkoutDraftNotifier notifier,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ExerciseSearchDialog(initialName: ex.name),
    );

    if (result != null && result['name'] != null) {
      notifier.updateExercise(
        index,
        ex.copyWith(
          name: result['name'],
          imageUrl: result['imageUrl'] ?? ex.imageUrl,
          localImagePath: result['localImagePath'] ?? ex.localImagePath,
        ),
      );
    }
  }

  Future<void> _showImageDialog(
    BuildContext context,
    int index,
    DraftExercise ex,
    WorkoutDraftNotifier notifier,
  ) async {
    final urlController = TextEditingController(text: ex.imageUrl ?? '');
    String? currentPreviewUrl = ex.imageUrl;
    String? currentLocalPath = ex.localImagePath;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Exercise Visuals'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((currentPreviewUrl != null &&
                          currentPreviewUrl!.isNotEmpty) ||
                      currentLocalPath != null)
                    Container(
                      height: 200,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        image: currentLocalPath != null
                            ? DecorationImage(
                                image: FileImage(File(currentLocalPath!)),
                                fit: BoxFit.cover,
                              )
                            : DecorationImage(
                                image: NetworkImage(currentPreviewUrl!),
                                fit: BoxFit.cover,
                              ),
                      ),
                    )
                  else
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No Image Selected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withAlpha(100),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "How to add a Web GIF/Image:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "1. Tap 'Search Web' below.\n2. Tap an image you like.\n3. Select 'Share' and choose 'Copy Link'.\n4. Come back and paste the link below.",
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Paste Image/GIF URL',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        currentPreviewUrl = val;
                        currentLocalPath = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.search),
                    label: const Text('Search Web for Image/GIF'),
                    onPressed: () async {
                      final query = Uri.encodeComponent(
                        '${ex.name} exercise gif',
                      );
                      final url = Uri.parse(
                        'https://www.google.com/search?tbm=isch&q=$query',
                      );
                      try {
                        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
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
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick from Device Gallery'),
                    onPressed: () async {
                      try {
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null) {
                          setState(() {
                            currentLocalPath = image.path;
                            currentPreviewUrl = null;
                            urlController.clear();
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to pick image.'),
                            ),
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              FilledButton(
                onPressed: () {
                  notifier.updateExercise(
                    index,
                    ex.copyWith(
                      imageUrl: currentPreviewUrl,
                      localImagePath: currentLocalPath,
                      clearImageUrl:
                          currentPreviewUrl == null ||
                          currentPreviewUrl!.isEmpty,
                      clearLocalImage: currentLocalPath == null,
                    ),
                  );
                  Navigator.pop(dialogContext);
                },
                child: const Text('Save Visual'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- NEW: PORTRAIT MODE REST DIALOG ---
  Future<void> _showRestDialog(
    BuildContext context,
    int index,
    DraftExercise ex,
    WorkoutDraftNotifier notifier,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exRestNext),
        content: _DurationInputRow(
          label: '',
          totalSeconds: ex.restSecondsExercise,
          onChanged: (val) => notifier.updateExercise(
            index,
            ex.copyWith(restSecondsExercise: val),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWorkout(List<DraftExercise> draftExercises) async {
    final l10n = AppLocalizations.of(context)!;
    if (draftExercises.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.builderEmptyMsg)));
      return;
    }

    final db = ref.read(databaseProvider);
    final title = _titleController.text.trim().isEmpty
        ? "My Custom Workout"
        : _titleController.text.trim();

    if (widget.onSaveDraft != null) {
      widget.onSaveDraft!(title, draftExercises);
      Navigator.pop(context);
      return;
    }

    try {
      await db.transaction(() async {
        int workoutId;

        if (widget.existingWorkoutId != null) {
          workoutId = widget.existingWorkoutId!;
          await (db.update(db.workouts)..where((t) => t.id.equals(workoutId)))
              .write(WorkoutsCompanion(title: drift.Value(title)));
          await (db.delete(
            db.workoutExercises,
          )..where((t) => t.workoutId.equals(workoutId))).go();
        } else {
          workoutId = await db
              .into(db.workouts)
              .insert(
                WorkoutsCompanion.insert(
                  title: title,
                  difficultyLevel: 'Custom',
                  aiGenerated: const drift.Value(false),
                ),
              );
        }

        for (int i = 0; i < draftExercises.length; i++) {
          final draftEx = draftExercises[i];
          int exerciseId;

          final existingEx =
              await (db.select(db.exercises)
                    ..where((t) => t.name.equals(draftEx.name))
                    ..limit(1))
                  .getSingleOrNull();

          if (existingEx != null) {
            exerciseId = existingEx.id;
            await (db.update(
              db.exercises,
            )..where((t) => t.id.equals(exerciseId))).write(
              ExercisesCompanion(
                imageUrl: drift.Value(draftEx.imageUrl),
                localImagePath: drift.Value(draftEx.localImagePath),
                equipment: drift.Value(draftEx.equipment),
                instructions: drift.Value(draftEx.instructions),
              ),
            );
          } else {
            exerciseId = await db
                .into(db.exercises)
                .insert(
                  ExercisesCompanion.insert(
                    name: draftEx.name,
                    muscleGroup: 'Custom',
                    isCustom: const drift.Value(true),
                    imageUrl: drift.Value(draftEx.imageUrl),
                    localImagePath: drift.Value(draftEx.localImagePath),
                    equipment: drift.Value(draftEx.equipment),
                    instructions: drift.Value(draftEx.instructions),
                  ),
                );
          }

          await db
              .into(db.workoutExercises)
              .insert(
                WorkoutExercisesCompanion.insert(
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
                  targetWeight: drift.Value(draftEx.targetWeight),
                ),
              );
        }
      });

      final profile = ref.read(userProfileProvider);
      if (profile.isAutoSyncEnabled) {
        final profileJsonString = jsonEncode(profile.toJson());
        ref.read(driveSyncProvider).backupToCloud(profileJsonString).ignore();
      }

      if (!mounted) return;

      ref.invalidate(dashboardControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout Saved Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- REBUILT EXERCISE FORM (Strict Grid & Hide Empty Rests) ---
  Widget _buildExerciseForm(
    DraftExercise ex,
    int index,
    AppLocalizations l10n,
    WorkoutDraftNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SwitchInputRow(
          label: l10n.exTimeBased,
          value: ex.isDuration,
          onChanged: (val) =>
              notifier.updateExercise(index, ex.copyWith(isDuration: val)),
        ),

        // Grid Row 1: Sets & Rest Between Sets
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberInputRow(
                label: l10n.exSets,
                value: ex.sets,
                onChanged: (val) =>
                    notifier.updateExercise(index, ex.copyWith(sets: val)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              // Completely hide the rest block if sets is 1, but preserve the Expanded grid layout!
              child: ex.sets > 1
                  ? _DurationInputRow(
                      label: l10n.exRestSets,
                      totalSeconds: ex.restSecondsSet,
                      onChanged: (val) => notifier.updateExercise(
                        index,
                        ex.copyWith(restSecondsSet: val),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),

        // Grid Row 2: Reps or Duration (Rest Before Next moved OUT)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ex.isDuration
                  ? _DurationInputRow(
                      label: l10n.exDuration,
                      totalSeconds: ex.durationSeconds ?? 30,
                      onChanged: (val) => notifier.updateExercise(
                        index,
                        ex.copyWith(durationSeconds: val),
                      ),
                    )
                  : _NumberInputRow(
                      label: l10n.exReps,
                      value: ex.reps,
                      onChanged: (val) => notifier.updateExercise(
                        index,
                        ex.copyWith(reps: val),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            // Empty placeholder to maintain the 50/50 grid look
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 16),

        // Grid Row 3: Equipment & Target Weight
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('eq_${ex.name}_$index'),
                initialValue: ex.equipment,
                decoration: InputDecoration(
                  labelText: l10n.exEquipment,
                  hintText: 'e.g. Barbell',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) => notifier.updateExercise(
                  index,
                  ex.copyWith(
                    equipment: val.trim(),
                    clearEquipment: val.trim().isEmpty,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                key: ValueKey('wt_${ex.name}_$index'),
                initialValue: ex.targetWeight?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.exTargetWeight,
                  hintText: 'e.g. 50',
                  suffixText: 'kg/lbs',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val.trim());
                  notifier.updateExercise(
                    index,
                    ex.copyWith(
                      targetWeight: parsed,
                      clearTargetWeight: parsed == null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grid Row 4: Instructions
        TextFormField(
          key: ValueKey('inst_${ex.name}_$index'),
          initialValue: ex.instructions,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.exInstructions,
            hintText: 'e.g. Keep your back straight, squeeze at the top.',
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) => notifier.updateExercise(
            index,
            ex.copyWith(
              instructions: val.trim(),
              clearInstructions: val.trim().isEmpty,
            ),
          ),
        ),
      ],
    );
  }

  // --- NEW: LANDSCAPE REST EDITOR ---
  Widget _buildRestEditor(
    DraftExercise ex,
    int index,
    AppLocalizations l10n,
    WorkoutDraftNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit Rest Period',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Rest duration after finishing ${ex.name} and before starting the next exercise.',
          style: const TextStyle(color: Colors.grey),
        ),
        const Divider(height: 32),
        _DurationInputRow(
          label: l10n.exRestNext,
          totalSeconds: ex.restSecondsExercise,
          onChanged: (val) => notifier.updateExercise(
            index,
            ex.copyWith(restSecondsExercise: val),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(DraftExercise ex) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: ex.localImagePath != null
          ? Image.file(File(ex.localImagePath!), fit: BoxFit.cover)
          : (ex.imageUrl != null && ex.imageUrl!.isNotEmpty)
          ? Image.network(
              ex.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) =>
                  const Icon(Icons.broken_image, color: Colors.red),
            )
          : const Icon(Icons.add_a_photo, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftExercises = ref.watch(workoutDraftProvider);
    final notifier = ref.read(workoutDraftProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingWorkoutId != null ? 'Edit Workout' : 'Build Workout',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveWorkout(draftExercises),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          if (isWide) {
            // ==========================================
            // MASTER-DETAIL LANDSCAPE VIEW
            // ==========================================
            return Row(
              children: [
                // LEFT: Master List
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: l10n.builderNameLabel,
                            border: const OutlineInputBorder(),
                            filled: true,
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: draftExercises.isEmpty
                            ? Center(child: Text(l10n.builderEmptyMsg))
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: draftExercises.length,
                                onReorder: (oldIndex, newIndex) {
                                  notifier.reorder(oldIndex, newIndex);
                                  if (_selectedDetailIndex == oldIndex) {
                                    _selectedDetailIndex = newIndex > oldIndex
                                        ? newIndex - 1
                                        : newIndex;
                                  }
                                },
                                itemBuilder: (context, index) {
                                  final ex = draftExercises[index];
                                  final isLast =
                                      index == draftExercises.length - 1;
                                  final isExerciseSelected =
                                      _selectedDetailType ==
                                          DetailType.exercise &&
                                      index == _selectedDetailIndex;
                                  final isRestSelected =
                                      _selectedDetailType == DetailType.rest &&
                                      index == _selectedDetailIndex;

                                  return Column(
                                    key: ValueKey('master_${ex.name}_$index'),
                                    children: [
                                      Card(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        color: isExerciseSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer
                                            : null,
                                        child: ListTile(
                                          leading: _buildThumbnail(ex),
                                          title: Text(
                                            ex.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            ex.isDuration
                                                ? '${ex.sets} Sets x ${ex.durationSeconds}s'
                                                : '${ex.sets} Sets x ${ex.reps} Reps',
                                          ),
                                          selected: isExerciseSelected,
                                          onTap: () => setState(() {
                                            _selectedDetailIndex = index;
                                            _selectedDetailType =
                                                DetailType.exercise;
                                          }),
                                          trailing: IconButton(
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
                                        ),
                                      ),
                                      // --- THE NEW REST DIVIDER BLOCK ---
                                      if (!isLast)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 32,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedDetailIndex = index;
                                                _selectedDetailType =
                                                    DetailType.rest;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isRestSelected
                                                    ? Colors.orange.withAlpha(
                                                        80,
                                                      )
                                                    : (ex.restSecondsExercise >
                                                              0
                                                          ? Colors.orange
                                                                .withAlpha(20)
                                                          : Colors.grey
                                                                .withAlpha(20)),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isRestSelected
                                                      ? Colors.orange
                                                      : (ex.restSecondsExercise >
                                                                0
                                                            ? Colors.orange
                                                                  .withAlpha(
                                                                    100,
                                                                  )
                                                            : Colors.grey
                                                                  .withAlpha(
                                                                    100,
                                                                  )),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.timer_outlined,
                                                    size: 16,
                                                    color:
                                                        ex.restSecondsExercise >
                                                            0
                                                        ? Colors.orange
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    ex.restSecondsExercise > 0
                                                        ? 'Rest: ${_formatTime(ex.restSecondsExercise)}'
                                                        : 'Add Rest',
                                                    style: TextStyle(
                                                      color:
                                                          ex.restSecondsExercise >
                                                              0
                                                          ? Colors.orange
                                                          : Colors.grey,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),

                // RIGHT: Detail Editor (Swaps between Exercise and Rest Editor)
                Expanded(
                  flex: 2,
                  child: draftExercises.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.fitness_center,
                            size: 100,
                            color: Colors.grey,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Card(
                            elevation: 0,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(80),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: _selectedDetailType == DetailType.rest
                                  ? _buildRestEditor(
                                      draftExercises[_selectedDetailIndex],
                                      _selectedDetailIndex,
                                      l10n,
                                      notifier,
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => _showTitleDialog(
                                                  context,
                                                  _selectedDetailIndex,
                                                  draftExercises[_selectedDetailIndex],
                                                  notifier,
                                                ),
                                                child: Text(
                                                  draftExercises[_selectedDetailIndex]
                                                      .name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.image),
                                              label: const Text('Edit Image'),
                                              onPressed: () => _showImageDialog(
                                                context,
                                                _selectedDetailIndex,
                                                draftExercises[_selectedDetailIndex],
                                                notifier,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 32),
                                        _buildExerciseForm(
                                          draftExercises[_selectedDetailIndex],
                                          _selectedDetailIndex,
                                          l10n,
                                          notifier,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          }

          // ==========================================
          // STANDARD PORTRAIT VIEW
          // ==========================================
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.builderNameLabel,
                    border: const OutlineInputBorder(),
                    filled: true,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: draftExercises.isEmpty
                    ? Center(child: Text(l10n.builderEmptyMsg))
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: draftExercises.length,
                        onReorder: (oldIndex, newIndex) =>
                            notifier.reorder(oldIndex, newIndex),
                        itemBuilder: (context, index) {
                          final ex = draftExercises[index];
                          final isLast = index == draftExercises.length - 1;

                          return Column(
                            key: ValueKey('ex_port_${ex.name}_$index'),
                            children: [
                              Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ExpansionTile(
                                  leading: InkWell(
                                    onTap: () => _showImageDialog(
                                      context,
                                      index,
                                      ex,
                                      notifier,
                                    ),
                                    child: _buildThumbnail(ex),
                                  ),
                                  title: Row(
                                    children: [
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
                                  subtitle: Text(
                                    ex.isDuration
                                        ? '${ex.sets} Sets x ${ex.durationSeconds}s'
                                        : '${ex.sets} Sets x ${ex.reps} Reps',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: _buildExerciseForm(
                                        ex,
                                        index,
                                        l10n,
                                        notifier,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // --- THE NEW REST DIVIDER BLOCK (PORTRAIT) ---
                              if (!isLast)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 32,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _showRestDialog(
                                      context,
                                      index,
                                      ex,
                                      notifier,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ex.restSecondsExercise > 0
                                            ? Colors.orange.withAlpha(20)
                                            : Colors.grey.withAlpha(20),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: ex.restSecondsExercise > 0
                                              ? Colors.orange.withAlpha(100)
                                              : Colors.grey.withAlpha(100),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.timer_outlined,
                                            size: 16,
                                            color: ex.restSecondsExercise > 0
                                                ? Colors.orange
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            ex.restSecondsExercise > 0
                                                ? 'Rest: ${_formatTime(ex.restSecondsExercise)}'
                                                : 'Add Rest',
                                            style: TextStyle(
                                              color: ex.restSecondsExercise > 0
                                                  ? Colors.orange
                                                  : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (context) => const _ExerciseSearchDialog(initialName: ''),
          );

          if (result != null && result['name'] != null) {
            notifier.addExercise(
              DraftExercise(
                name: result['name'],
                imageUrl: result['imageUrl'],
                localImagePath: result['localImagePath'],
              ),
            );
            setState(() {
              _selectedDetailIndex = draftExercises.length;
              _selectedDetailType = DetailType.exercise;
            });
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.builderAddBtn),
      ),
    );
  }
}
// -----------------------------------------------------------------------------
// REUSABLE INPUT WIDGETS (FittedBox prevents overflow without scrolling!)
// -----------------------------------------------------------------------------

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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ensure labels truncate cleanly instead of overflowing
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withAlpha(128),
              borderRadius: BorderRadius.circular(12),
            ),
            // FIX: FittedBox scales the counter down gracefully on tiny screens
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    onTap: () => onChanged((value - 1).clamp(1, 999)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Icon(Icons.remove, size: 18),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: TextFormField(
                      key: ValueKey(value.toString()),
                      initialValue: value.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onFieldSubmitted: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) onChanged(parsed.clamp(1, 999));
                      },
                    ),
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                    onTap: () => onChanged(value + 1),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationInputRow extends StatelessWidget {
  final String label;
  final int totalSeconds;
  final ValueChanged<int> onChanged;

  const _DurationInputRow({
    required this.label,
    required this.totalSeconds,
    required this.onChanged,
  });

  String _format(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m > 0 && s > 0) return '${m}m ${s}s';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (label.isNotEmpty) const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withAlpha(128),
              borderRadius: BorderRadius.circular(12),
            ),
            // FIX: Unified single compact control wrapped in a FittedBox
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    onTap: () => onChanged((totalSeconds - 15).clamp(5, 3600)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Icon(Icons.remove, size: 18),
                    ),
                  ),
                  Container(
                    width: 56, // Enough space to comfortably fit "1m 30s"
                    alignment: Alignment.center,
                    child: Text(
                      _format(totalSeconds),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                    onTap: () => onChanged((totalSeconds + 15).clamp(5, 3600)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchInputRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchInputRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            height: 42,
            alignment: Alignment.centerLeft,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SEARCH DIALOG (Unchanged logic, just UI tweaks)
// -----------------------------------------------------------------------------

class _ExerciseSearchDialog extends ConsumerStatefulWidget {
  final String initialName;

  const _ExerciseSearchDialog({required this.initialName});

  @override
  ConsumerState<_ExerciseSearchDialog> createState() =>
      _ExerciseSearchDialogState();
}

class _ExerciseSearchDialogState extends ConsumerState<_ExerciseSearchDialog> {
  late TextEditingController _controller;
  List<dynamic> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);

    if (widget.initialName.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
      _search(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);

    final results =
        await (db.select(db.exercises)
              ..where((t) => t.name.like('%${query.trim()}%'))
              ..limit(10))
            .get();

    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  ImageProvider? _getImageProvider(String? localPath, String? networkUrl) {
    if (localPath != null && localPath.isNotEmpty) {
      return FileImage(File(localPath));
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return NetworkImage(networkUrl);
    }
    return null;
  }

  void _submitCustom() {
    if (_controller.text.trim().isNotEmpty) {
      Navigator.pop(context, {
        'name': _controller.text.trim(),
        'imageUrl': null,
        'localImagePath': null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type exercise name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    color: Colors.blueAccent,
                  ),
                  onPressed: _submitCustom,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: _search,
              onSubmitted: (_) => _submitCustom(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _suggestions.isEmpty && _controller.text.isNotEmpty
                  ? Center(
                      child: Text(
                        'No matches found.\nTap the checkmark to create "${_controller.text.trim()}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final ex = _suggestions[index];
                        final imgProvider = _getImageProvider(
                          ex.localImagePath,
                          ex.imageUrl,
                        );

                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              image: imgProvider != null
                                  ? DecorationImage(
                                      image: imgProvider,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imgProvider == null
                                ? const Icon(
                                    Icons.fitness_center,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          title: Text(
                            ex.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            ex.muscleGroup ?? 'Global Database',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(context, {
                              'name': ex.name,
                              'imageUrl': ex.imageUrl,
                              'localImagePath': ex.localImagePath,
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
