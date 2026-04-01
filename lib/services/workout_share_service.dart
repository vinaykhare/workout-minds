import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:workout_minds/data/local/database.dart';

class WorkoutShareService {
  final AppDatabase _db;

  WorkoutShareService(this._db);

  // ==========================================
  // 1. EXPORT WORKOUT TO .wmind FILE
  // ==========================================
  Future<bool> exportAndShare(int workoutId) async {
    try {
      // 1. Fetch the Workout
      final workout = await (_db.select(
        _db.workouts,
      )..where((t) => t.id.equals(workoutId))).getSingle();

      // 2. Fetch the Mapping and Exercises
      final mappings = await (_db.select(
        _db.workoutExercises,
      )..where((t) => t.workoutId.equals(workoutId))).get();

      List<Map<String, dynamic>> exerciseList = [];
      for (var map in mappings) {
        final ex = await (_db.select(
          _db.exercises,
        )..where((t) => t.id.equals(map.exerciseId))).getSingle();
        exerciseList.add({
          'name': ex.name,
          'muscleGroup': ex.muscleGroup,
          'imageUrl': ex.imageUrl,
          'targetSets': map.targetSets,
          'targetReps': map.targetReps,
          'targetDurationSeconds': map.targetDurationSeconds,
          'restSecondsAfterSet': map.restSecondsAfterSet,
          'restSecondsAfterExercise': map.restSecondsAfterExercise,
          'orderIndex': map.orderIndex,
        });
      }

      // 3. Create the JSON Payload
      final payload = {
        'version': 1,
        'app': 'workout_minds',
        'workout': {
          'title': workout.title,
          'difficultyLevel': workout.difficultyLevel,
        },
        'exercises': exerciseList,
      };

      // 4. Write to a Temporary File
      final tempDir = await getTemporaryDirectory();
      // Sanitize the filename
      final safeName = workout.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${tempDir.path}/$safeName.wmind');
      await file.writeAsString(jsonEncode(payload));

      // 5. Open Native Share Sheet (Updated for share_plus v10+)
      final params = ShareParams(
        files: [XFile(file.path)],
        subject: 'Check out my workout on Workout Minds!',
        text: 'Check out my workout on Workout Minds!',
      );

      await SharePlus.instance.share(params);

      return true;
    } catch (e) {
      // FIX: Use debugPrint instead of print for production safety
      debugPrint("Export Error: $e");
      return false;
    }
  }

  // ==========================================
  // 2. IMPORT WORKOUT FROM FILE PATH
  // ==========================================
  Future<String> importFromFilePath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) throw Exception("File not found.");

      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data['app'] != 'workout_minds') {
        throw Exception("Invalid file format. Not a Workout Minds file.");
      }

      final workoutData = data['workout'];
      final exercisesData = data['exercises'] as List<dynamic>;

      // Wrap insertion in a transaction
      await _db.transaction(() async {
        // Insert Workout
        final newWorkoutId = await _db
            .into(_db.workouts)
            .insert(
              WorkoutsCompanion.insert(
                title: "${workoutData['title']} (Imported)",
                difficultyLevel: workoutData['difficultyLevel'] ?? 'Custom',
                aiGenerated: const Value(false),
              ),
            );

        // Process Exercises
        for (var exData in exercisesData) {
          int exId;

          // Check global dictionary
          final existingEx =
              await (_db.select(_db.exercises)
                    ..where((t) => t.name.equals(exData['name']))
                    ..limit(1))
                  .getSingleOrNull();

          if (existingEx != null) {
            exId = existingEx.id;
          } else {
            exId = await _db
                .into(_db.exercises)
                .insert(
                  ExercisesCompanion.insert(
                    name: exData['name'],
                    muscleGroup: exData['muscleGroup'] ?? 'Custom',
                    imageUrl: Value(exData['imageUrl']),
                    isCustom: const Value(true),
                  ),
                );
          }

          // Link to workout
          await _db
              .into(_db.workoutExercises)
              .insert(
                WorkoutExercisesCompanion.insert(
                  workoutId: newWorkoutId,
                  exerciseId: exId,
                  orderIndex: exData['orderIndex'],
                  targetSets: exData['targetSets'],
                  targetReps: Value(exData['targetReps']),
                  targetDurationSeconds: Value(exData['targetDurationSeconds']),
                  restSecondsAfterSet: exData['restSecondsAfterSet'] ?? 60,
                  restSecondsAfterExercise:
                      exData['restSecondsAfterExercise'] ?? 90,
                ),
              );
        }
      });

      return "Success";
    } catch (e) {
      return "Error importing workout: $e";
    }
  }

  // ==========================================
  // 3. MANUAL IMPORT TRIGGER (File Picker)
  // ==========================================
  Future<String?> pickAndImportWorkout() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // Android file pickers are finicky with custom extensions, 'any' is safest
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!path.endsWith('.wmind')) {
          return "Please select a valid .wmind file.";
        }
        return await importFromFilePath(path);
      }
      return null; // User canceled
    } catch (e) {
      return "Error picking file: $e";
    }
  }

  // ==========================================
  // 4. SAVE WORKOUT TO DISK (Download)
  // ==========================================
  Future<bool> saveToDisk(int workoutId) async {
    try {
      // 1. Fetch the Workout and Exercises (Reuse logic or refactor to helper)
      final workout = await (_db.select(
        _db.workouts,
      )..where((t) => t.id.equals(workoutId))).getSingle();
      final mappings = await (_db.select(
        _db.workoutExercises,
      )..where((t) => t.workoutId.equals(workoutId))).get();

      List<Map<String, dynamic>> exerciseList = [];
      for (var map in mappings) {
        final ex = await (_db.select(
          _db.exercises,
        )..where((t) => t.id.equals(map.exerciseId))).getSingle();
        exerciseList.add({
          'name': ex.name,
          'muscleGroup': ex.muscleGroup,
          'imageUrl': ex.imageUrl,
          'targetSets': map.targetSets,
          'targetReps': map.targetReps,
          'targetDurationSeconds': map.targetDurationSeconds,
          'restSecondsAfterSet': map.restSecondsAfterSet,
          'restSecondsAfterExercise': map.restSecondsAfterExercise,
          'orderIndex': map.orderIndex,
        });
      }

      final payload = {
        'version': 1,
        'app': 'workout_minds',
        'workout': {
          'title': workout.title,
          'difficultyLevel': workout.difficultyLevel,
        },
        'exercises': exerciseList,
      };

      // 2. Open "Save As" Dialog
      final safeName = workout.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      // This opens the native Save File picker
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Workout File',
        fileName: '$safeName.wmind',
        type: FileType
            .any, // Extension filtering is handled by the fileName parameter on most OS
      );

      if (outputFile == null) return false; // User canceled

      // 3. Write the file to the chosen path
      final file = File(outputFile);
      await file.writeAsString(jsonEncode(payload));

      return true;
    } catch (e) {
      debugPrint("Save to Disk Error: $e");
      return false;
    }
  }
}
