import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:drift/drift.dart' as drift; // <--- Add this import

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
  // 2. MANUAL IMPORT TRIGGER (File Picker)
  // ==========================================
  Future<Map<String, dynamic>?> pickAndImportWorkout() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // Android file pickers are finicky with custom extensions, 'any' is safest
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        // Check extension just for manual file picker to be safe
        if (!path.endsWith('.wmind')) {
          return null;
        }
        // Instead of saving, we just return the parsed JSON!
        return await parseWorkoutFile(path);
      }
      return null; // User canceled
    } catch (e) {
      debugPrint("Error picking file: $e");
      return null;
    }
  }

  // Just reads and validates the file, returns the raw data
  Future<Map<String, dynamic>?> parseWorkoutFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data['app'] != 'workout_minds') return null;
      return data;
    } catch (e) {
      debugPrint("Parse Error: $e");
      return null;
    }
  }

  // ==========================================
  // 4. SAVE WORKOUT TO DISK (Download)
  // ==========================================
  // ==========================================
  // 4. SAVE WORKOUT TO DISK (Download)
  // ==========================================
  Future<bool> saveToDisk(int workoutId) async {
    try {
      // 1. Fetch the Workout and Exercises
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

      // 2. Format the filename safely
      final safeName = workout.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      // 3. Save based on Platform
      if (Platform.isAndroid) {
        // Direct write to public downloads on Android
        final dir = Directory('/storage/emulated/0/Download');

        // Ensure the directory exists (it almost always does, but safety first)
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // Add a timestamp so we don't overwrite previous downloads of the same workout
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/${safeName}_$timestamp.wmind');

        await file.writeAsString(jsonEncode(payload));
        return true;
      } else {
        // Use standard FilePicker for Windows/Desktop
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Workout File',
          fileName: '$safeName.wmind',
          type: FileType.any,
        );

        if (outputFile == null) return false; // User canceled

        // Write the file to the chosen path
        final file = File(outputFile);
        await file.writeAsString(jsonEncode(payload));
        return true;
      }
    } catch (e) {
      debugPrint("Save to Disk Error: $e");
      return false;
    }
  }

  // ==========================================
  // 5. EXPORT WORKOUT PLAN
  // ==========================================
  Future<bool> exportAndSharePlan(int planId) async {
    try {
      final plan = await (_db.select(
        _db.workoutPlans,
      )..where((t) => t.id.equals(planId))).getSingle();
      final days = await (_db.select(
        _db.workoutPlanDays,
      )..where((t) => t.planId.equals(planId))).get();

      final workoutIds = days
          .map((d) => d.workoutId)
          .whereType<int>()
          .toSet()
          .toList();

      Map<String, dynamic> workoutsMap = {};
      Map<int, String> oldIdToRef = {};

      for (int wId in workoutIds) {
        final w = await (_db.select(
          _db.workouts,
        )..where((t) => t.id.equals(wId))).getSingle();
        final mappings = await (_db.select(
          _db.workoutExercises,
        )..where((t) => t.workoutId.equals(wId))).get();

        List<Map<String, dynamic>> exList = [];
        for (var map in mappings) {
          final ex = await (_db.select(
            _db.exercises,
          )..where((t) => t.id.equals(map.exerciseId))).getSingle();
          exList.add({
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

        String refKey = 'w_$wId';
        oldIdToRef[wId] = refKey;
        workoutsMap[refKey] = {
          'title': w.title,
          'difficultyLevel': w.difficultyLevel,
          'exercises': exList,
        };
      }

      List<Map<String, dynamic>> scheduleList = days
          .map(
            (d) => {
              'dayNumber': d.dayNumber,
              'workoutRef': d.workoutId != null
                  ? oldIdToRef[d.workoutId]
                  : null,
              'notes': d.notes,
            },
          )
          .toList();

      final payload = {
        'version': 1,
        'app': 'workout_minds',
        'type': 'plan', // <--- Identifies it as a Plan
        'plan': {
          'title': plan.title,
          'description': plan.description,
          'goal': plan.goal,
          'totalWeeks': plan.totalWeeks,
        },
        'workouts': workoutsMap,
        'schedule': scheduleList,
      };

      final tempDir = await getTemporaryDirectory();
      final safeName = plan.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${tempDir.path}/${safeName}_Plan.wmind');
      await file.writeAsString(jsonEncode(payload));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Check out my training plan!',
        ),
      );
      return true;
    } catch (e) {
      debugPrint("Plan Export Error: $e");
      return false;
    }
  }

  // ==========================================
  // 6. SAVE PLAN TO DISK
  // ==========================================
  Future<bool> savePlanToDisk(int planId) async {
    try {
      // 1. Fetch all the Plan Data (Same logic as Export)
      final plan = await (_db.select(
        _db.workoutPlans,
      )..where((t) => t.id.equals(planId))).getSingle();
      final days = await (_db.select(
        _db.workoutPlanDays,
      )..where((t) => t.planId.equals(planId))).get();

      final workoutIds = days
          .map((d) => d.workoutId)
          .whereType<int>()
          .toSet()
          .toList();

      Map<String, dynamic> workoutsMap = {};
      Map<int, String> oldIdToRef = {};

      // Extract all the deep workout and exercise data
      for (int wId in workoutIds) {
        final w = await (_db.select(
          _db.workouts,
        )..where((t) => t.id.equals(wId))).getSingle();
        final mappings = await (_db.select(
          _db.workoutExercises,
        )..where((t) => t.workoutId.equals(wId))).get();

        List<Map<String, dynamic>> exList = [];
        for (var map in mappings) {
          final ex = await (_db.select(
            _db.exercises,
          )..where((t) => t.id.equals(map.exerciseId))).getSingle();
          exList.add({
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

        String refKey = 'w_$wId';
        oldIdToRef[wId] = refKey;
        workoutsMap[refKey] = {
          'title': w.title,
          'difficultyLevel': w.difficultyLevel,
          'exercises': exList,
        };
      }

      List<Map<String, dynamic>> scheduleList = days
          .map(
            (d) => {
              'dayNumber': d.dayNumber,
              'workoutRef': d.workoutId != null
                  ? oldIdToRef[d.workoutId]
                  : null,
              'notes': d.notes,
            },
          )
          .toList();

      final payload = {
        'version': 1,
        'app': 'workout_minds',
        'type': 'plan',
        'plan': {
          'title': plan.title,
          'description': plan.description,
          'goal': plan.goal,
          'totalWeeks': plan.totalWeeks,
        },
        'workouts': workoutsMap,
        'schedule': scheduleList,
      };

      // 2. Format the filename safely
      final safeName = plan.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      // 3. Save based on Platform
      if (Platform.isAndroid) {
        // Direct write to public downloads on Android
        final dir = Directory('/storage/emulated/0/Download');

        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/${safeName}_Plan_$timestamp.wmind');

        await file.writeAsString(jsonEncode(payload));
        return true;
      } else {
        // --- FIX: Use standard FilePicker for Windows/Desktop! ---
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Workout Plan File',
          fileName: '${safeName}_Plan.wmind',
          type: FileType.any,
        );

        if (outputFile == null) return false; // User canceled

        final file = File(outputFile);
        await file.writeAsString(jsonEncode(payload));
        return true;
      }
    } catch (e) {
      debugPrint("Save Plan to Disk Error: $e");
      return false;
    }
  }

  // ==========================================
  // 7. IMPORT PLAN TO DATABASE
  // ==========================================
  Future<int> saveImportedPlanToDb(Map<String, dynamic> data) async {
    return await _db.transaction(() async {
      final planData = data['plan'];

      // --- 1. SMART PLAN NAMING (Suffix Logic) ---
      final String basePlanTitle = planData['title']?.trim() ?? 'Imported Plan';
      String finalPlanTitle = basePlanTitle;
      int planCounter = 1;

      while (true) {
        final exists = await (_db.select(
          _db.workoutPlans,
        )..where((t) => t.title.equals(finalPlanTitle))).getSingleOrNull();

        if (exists == null) break; // Unique name found!

        finalPlanTitle = '$basePlanTitle ($planCounter)';
        planCounter++;
      }

      // Insert the Plan with the guaranteed unique title
      final planId = await _db
          .into(_db.workoutPlans)
          .insert(
            WorkoutPlansCompanion.insert(
              title: finalPlanTitle,
              description: drift.Value(planData['description']),
              goal: drift.Value(planData['goal']),
              totalWeeks: drift.Value(planData['totalWeeks'] ?? 4),
            ),
          );

      final workoutsData = data['workouts'] as Map<String, dynamic>;
      Map<String, int> refToDbId = {};

      for (var entry in workoutsData.entries) {
        final refKey = entry.key;
        final wData = entry.value;

        // --- 2. SMART WORKOUT NAMING (Prefix Logic) ---
        final String baseWorkoutTitle = wData['title']?.trim() ?? 'Workout';
        String finalWorkoutTitle = baseWorkoutTitle;

        final existingWorkout =
            await (_db.select(_db.workouts)
                  ..where((t) => t.title.equals(finalWorkoutTitle))
                  ..limit(1))
                .getSingleOrNull();

        // If it exists, prefix it with the Plan name! (e.g., "Summer Shred: Leg Day")
        if (existingWorkout != null) {
          finalWorkoutTitle = '$basePlanTitle: $baseWorkoutTitle';

          // Fallback: If they imported the exact same plan twice, add a suffix to the workout too
          int wCounter = 1;
          String tempWTitle = finalWorkoutTitle;
          while (true) {
            final wExists =
                await (_db.select(_db.workouts)
                      ..where((t) => t.title.equals(tempWTitle))
                      ..limit(1))
                    .getSingleOrNull();
            if (wExists == null) {
              finalWorkoutTitle = tempWTitle;
              break;
            }
            tempWTitle = '$basePlanTitle: $baseWorkoutTitle ($wCounter)';
            wCounter++;
          }
        }

        // Insert the highly-isolated, uniquely named Workout!
        final wId = await _db
            .into(_db.workouts)
            .insert(
              WorkoutsCompanion.insert(
                title: finalWorkoutTitle,
                difficultyLevel: wData['difficultyLevel'] ?? 'Custom',
                aiGenerated: const drift.Value(false),
              ),
            );
        refToDbId[refKey] = wId;

        // --- 3. EXERCISE DEDUPLICATION (The Upsert) ---
        // Exercises remain strictly deduplicated to keep the library clean!
        final exList = wData['exercises'] as List<dynamic>;
        for (int i = 0; i < exList.length; i++) {
          final exData = exList[i];
          final existingEx =
              await (_db.select(_db.exercises)
                    ..where((t) => t.name.equals(exData['name']))
                    ..limit(1))
                  .getSingleOrNull();

          int exId;
          if (existingEx != null) {
            exId = existingEx.id;
            // Update the global exercise with any new images/instructions the user added
            await (_db.update(
              _db.exercises,
            )..where((t) => t.id.equals(exId))).write(
              ExercisesCompanion(
                imageUrl: drift.Value(exData['imageUrl']),
                localImagePath: drift.Value(exData['localImagePath']),
                equipment: drift.Value(exData['equipment']),
                instructions: drift.Value(exData['instructions']),
              ),
            );
          } else {
            // Create a brand new global exercise
            exId = await _db
                .into(_db.exercises)
                .insert(
                  ExercisesCompanion.insert(
                    name: exData['name'],
                    muscleGroup: exData['muscleGroup'] ?? 'Custom',
                    isCustom: const drift.Value(true),
                    imageUrl: drift.Value(exData['imageUrl']),
                    localImagePath: drift.Value(exData['localImagePath']),
                    equipment: drift.Value(exData['equipment']),
                    instructions: drift.Value(exData['instructions']),
                  ),
                );
          }

          // Link the exercise to the workout
          await _db
              .into(_db.workoutExercises)
              .insert(
                WorkoutExercisesCompanion.insert(
                  workoutId: wId,
                  exerciseId: exId,
                  orderIndex: i,
                  targetSets: exData['targetSets'],
                  targetReps: drift.Value(exData['targetReps']),
                  targetDurationSeconds: drift.Value(
                    exData['targetDurationSeconds'],
                  ),
                  targetWeight: drift.Value(
                    (exData['targetWeight'] as num?)?.toDouble(),
                  ),
                  restSecondsAfterSet: exData['restSecondsAfterSet'] ?? 60,
                  restSecondsAfterExercise:
                      exData['restSecondsAfterExercise'] ?? 90,
                ),
              );
        }
      }

      // --- 4. MAP THE SCHEDULE ---
      final scheduleData = data['schedule'] as List<dynamic>;
      for (var day in scheduleData) {
        final refKey = day['workoutRef'];
        await _db
            .into(_db.workoutPlanDays)
            .insert(
              WorkoutPlanDaysCompanion.insert(
                planId: planId,
                dayNumber: day['dayNumber'],
                workoutId: drift.Value(
                  refKey != null ? refToDbId[refKey] : null,
                ),
                notes: drift.Value(day['notes']),
              ),
            );
      }
      return planId;
    });
  }
}
