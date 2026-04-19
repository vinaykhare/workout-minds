import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';

class AIPlanRepository {
  final GenerativeModel _model;
  final AppDatabase _db;

  AIPlanRepository(this._model, this._db);

  // FIX 1: Pass the UserProfile in so the AI knows their stats!
  Future<int> generateAndSavePlan(
    String userPrompt,
    UserProfile profile,
  ) async {
    try {
      // --- 1. THE SMART ADAPT LOOP (Fetch Historical Feedback) ---
      final recentLogs =
          await (_db.select(_db.workoutLogs)
                ..orderBy([(t) => OrderingTerm.desc(t.executedAt)])
                ..limit(20))
              .get();

      String feedbackContext = "";
      bool hasFeedback = false;

      for (var log in recentLogs) {
        if (log.executionFeedback != null &&
            log.executionFeedback!.length > 5) {
          if (!hasFeedback) {
            feedbackContext =
                "\n--- PAST PERFORMANCE FEEDBACK (CRITICAL) ---\n";
            feedbackContext +=
                "The user recently struggled with or breezed through the following exercises. YOU MUST adapt this new plan's sets, reps, duration, or weights based on these realities (Progressive Overload or Regression):\n";
            hasFeedback = true;
          }
          try {
            final Map<String, dynamic> feedbackMap = jsonDecode(
              log.executionFeedback!,
            );
            feedbackMap.forEach((exercise, note) {
              feedbackContext += "- $exercise: $note\n";
            });
          } catch (_) {
            // Ignore malformed JSON
          }
        }
      }

      // --- 2. ASSEMBLE THE SUPER-PROMPT ---
      final prompt =
          '''
      You are an elite AI personal trainer. 
      Create a highly structured workout plan based on this request: "$userPrompt".
      
      --- USER PROFILE ---
      Gender: ${profile.gender}
      Goal: ${profile.goal}
      Preferred Style/Equipment: ${profile.preferredStyle}
      Max Pushups (Upper Body Pushing): ${profile.pushupCapacity}
      Max Pull-ups (Upper Body Pulling): ${profile.pullupCapacity}
      Max Bodyweight Squats (Lower Body): ${profile.squatCapacity}
      Height: ${profile.heightCm} cm
      Weight: ${profile.weightKg} kg
      BMI: ${profile.bmi.toStringAsFixed(1)}
      $feedbackContext

      Ensure the weekly schedule includes rest days to allow for recovery.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception("AI returned an empty response.");
      }

      // Parse the strict JSON
      final Map<String, dynamic> data = jsonDecode(responseText);

      // We will return the new Plan ID so the UI can navigate to it
      int newPlanId = -1;

      // 3. Perform the massive database insertion safely inside a transaction!
      await _db.transaction(() async {
        // A. Insert the Umbrella Plan
        newPlanId = await _db
            .into(_db.workoutPlans)
            .insert(
              WorkoutPlansCompanion.insert(
                title: data['plan_title'],
                description: Value(data['plan_description']),
                goal: Value(data['plan_goal']),
                totalWeeks: Value(data['total_weeks'] ?? 4),
              ),
            );

        // B. Insert the Unique Workouts and cache their IDs
        // We use a Map to remember which AI Workout Title matches which SQLite Workout ID
        Map<String, int> workoutIdMap = {};

        for (var workoutData in data['unique_workouts']) {
          final workoutTitle = workoutData['workout_title'];

          final workoutId = await _db
              .into(_db.workouts)
              .insert(
                WorkoutsCompanion.insert(
                  title: workoutTitle,
                  difficultyLevel:
                      workoutData['difficulty_level'] ?? 'Intermediate',
                  aiGenerated: const Value(true),
                ),
              );

          workoutIdMap[workoutTitle] = workoutId;

          // C. Insert the Exercises for this specific workout
          int orderIndex = 0;
          for (var exData in workoutData['exercises']) {
            int exerciseId;

            // Check if exercise already exists in global library
            final existingEx =
                await (_db.select(_db.exercises)
                      ..where((t) => t.name.equals(exData['exercise_name']))
                      ..limit(1))
                    .getSingleOrNull();

            if (existingEx != null) {
              exerciseId = existingEx.id;
            } else {
              exerciseId = await _db
                  .into(_db.exercises)
                  .insert(
                    ExercisesCompanion.insert(
                      name: exData['exercise_name'],
                      muscleGroup: exData['muscleGroup'] ?? 'Custom',
                      isCustom: const Value(false),
                      // imageUrl: Value(exData['image_url']),
                      imageUrl: const Value(null),
                      equipment: Value(exData['equipment']),
                      instructions: Value(exData['instructions']),
                    ),
                  );
            }

            // Link exercise to workout
            await _db
                .into(_db.workoutExercises)
                .insert(
                  WorkoutExercisesCompanion.insert(
                    workoutId: workoutId,
                    exerciseId: exerciseId,
                    orderIndex: orderIndex++,
                    targetSets: exData['target_sets'],
                    targetReps: Value(exData['target_reps']),
                    targetDurationSeconds: Value(
                      exData['target_duration_seconds'],
                    ),
                    targetWeight: Value(
                      (exData['target_weight'] as num?)?.toDouble(),
                    ),
                    restSecondsAfterSet: exData['rest_seconds_set'] ?? 60,
                    restSecondsAfterExercise:
                        exData['rest_seconds_exercise'] ?? 90,
                  ),
                );
          }
        }

        // D. The Magic: "Unroll" the 7-day schedule into a full multi-week calendar!
        final totalWeeks = data['total_weeks'] as int;
        final weeklySchedule = data['weekly_schedule'] as List<dynamic>;

        int absoluteDayCounter = 1;

        for (int week = 0; week < totalWeeks; week++) {
          for (var dayData in weeklySchedule) {
            final targetWorkoutTitle = dayData['workout_title'];

            // If the title is "REST" or it doesn't match our Map, we leave it null (Rest Day)
            final mappedWorkoutId = workoutIdMap[targetWorkoutTitle];

            await _db
                .into(_db.workoutPlanDays)
                .insert(
                  WorkoutPlanDaysCompanion.insert(
                    planId: newPlanId,
                    dayNumber: absoluteDayCounter++,
                    workoutId: Value(
                      mappedWorkoutId,
                    ), // Will insert NULL if it's a rest day
                    notes: Value(dayData['notes']),
                  ),
                );
          }
        }
      });

      return newPlanId;
    } catch (e) {
      debugPrint("AI Plan Generation Error: $e");
      throw Exception("Failed to generate plan. Please try again.");
    }
  }

  // =====================================================================
  // MID-PLAN OPTIMIZATION LOOP
  // =====================================================================
  Future<void> optimizePlan(int planId, UserProfile profile) async {
    try {
      // 1. Fetch the current plan metadata
      final plan = await _db.getPlan(planId);

      // 2. Fetch the recent execution feedback
      final recentLogs =
          await (_db.select(_db.workoutLogs)
                ..where((t) => t.executionFeedback.isNotNull())
                ..orderBy([(t) => OrderingTerm.desc(t.executedAt)])
                ..limit(20))
              .get();

      String feedbackContext = "";
      for (var log in recentLogs) {
        if (log.executionFeedback != null &&
            log.executionFeedback!.length > 5) {
          try {
            final Map<String, dynamic> feedbackMap = jsonDecode(
              log.executionFeedback!,
            );
            feedbackMap.forEach((exercise, note) {
              feedbackContext += "- $exercise: $note\n";
            });
          } catch (_) {}
        }
      }

      if (feedbackContext.trim().isEmpty) {
        throw Exception(
          "No execution feedback found yet! Log some 'Too Hard' or 'Too Easy' issues during a workout first.",
        );
      }

      // 3. Prompt Gemini to adapt the plan
      final prompt =
          '''
      You are an elite AI personal trainer. 
      The user is currently on a ${plan.totalWeeks}-week plan titled "${plan.title}" with the goal of "${plan.goal}".

      --- USER PROFILE ---
      Gender: ${profile.gender}
      Goal: ${profile.goal}
      Preferred Style/Equipment: ${profile.preferredStyle}
      Max Pushups (Upper Body Pushing): ${profile.pushupCapacity}
      Max Pull-ups (Upper Body Pulling): ${profile.pullupCapacity}
      Max Bodyweight Squats (Lower Body): ${profile.squatCapacity}
      Height: ${profile.heightCm} cm
      Weight: ${profile.weightKg} kg
      BMI: ${profile.bmi.toStringAsFixed(1)}
      --- CRITICAL RECENT FEEDBACK ---
      The user recently struggled with or breezed through the following exercises:
      $feedbackContext

      Your task is to REWRITE and OPTIMIZE their ${plan.totalWeeks}-week plan. 
      You MUST adjust the target sets, reps, durations, weights, or swap exercises entirely based on the feedback provided above (Apply Progressive Overload or Regression).
      Output the new plan using the exact same JSON schema.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception("AI returned an empty response.");
      }

      final Map<String, dynamic> data = jsonDecode(responseText);

      // 4. Safely apply the changes to the database
      await _db.transaction(() async {
        // Update the plan description to show it was optimized
        await (_db.update(
          _db.workoutPlans,
        )..where((t) => t.id.equals(planId))).write(
          WorkoutPlansCompanion(
            description: Value(
              "✨ Optimized by AI based on recent feedback.\n${data['plan_description']}",
            ),
          ),
        );

        // Wipe the old calendar schedule
        await (_db.delete(
          _db.workoutPlanDays,
        )..where((t) => t.planId.equals(planId))).go();

        Map<String, int> workoutIdMap = {};

        // Insert the newly adapted workouts
        for (var workoutData in data['unique_workouts']) {
          final workoutTitle = workoutData['workout_title'];

          final newWorkoutId = await _db
              .into(_db.workouts)
              .insert(
                WorkoutsCompanion.insert(
                  title: workoutTitle,
                  difficultyLevel: workoutData['difficulty_level'] ?? 'Adapted',
                  aiGenerated: const Value(true),
                ),
              );

          workoutIdMap[workoutTitle] = newWorkoutId;

          int orderIndex = 0;
          for (var exData in workoutData['exercises']) {
            int exerciseId;
            final existingEx =
                await (_db.select(_db.exercises)
                      ..where((t) => t.name.equals(exData['exercise_name']))
                      ..limit(1))
                    .getSingleOrNull();

            if (existingEx != null) {
              exerciseId = existingEx.id;
            } else {
              exerciseId = await _db
                  .into(_db.exercises)
                  .insert(
                    ExercisesCompanion.insert(
                      name: exData['exercise_name'],
                      muscleGroup: exData['muscleGroup'] ?? 'Custom',
                      isCustom: const Value(false),
                      // imageUrl: Value(exData['image_url']),
                      imageUrl: const Value(null),
                      equipment: Value(exData['equipment']),
                      instructions: Value(exData['instructions']),
                    ),
                  );
            }

            await _db
                .into(_db.workoutExercises)
                .insert(
                  WorkoutExercisesCompanion.insert(
                    workoutId: newWorkoutId,
                    exerciseId: exerciseId,
                    orderIndex: orderIndex++,
                    targetSets: exData['target_sets'],
                    targetReps: Value(exData['target_reps']),
                    targetDurationSeconds: Value(
                      exData['target_duration_seconds'],
                    ),
                    targetWeight: Value(
                      (exData['target_weight'] as num?)?.toDouble(),
                    ),
                    restSecondsAfterSet: exData['rest_seconds_set'] ?? 60,
                    restSecondsAfterExercise:
                        exData['rest_seconds_exercise'] ?? 90,
                  ),
                );
          }
        }

        // Unroll the new schedule
        final weeklySchedule = data['weekly_schedule'] as List<dynamic>;
        int absoluteDayCounter = 1;

        for (int week = 0; week < plan.totalWeeks; week++) {
          for (var dayData in weeklySchedule) {
            final targetWorkoutTitle = dayData['workout_title'];
            final mappedWorkoutId = workoutIdMap[targetWorkoutTitle];

            await _db
                .into(_db.workoutPlanDays)
                .insert(
                  WorkoutPlanDaysCompanion.insert(
                    planId: planId,
                    dayNumber: absoluteDayCounter++,
                    workoutId: Value(mappedWorkoutId),
                    notes: Value(dayData['notes']),
                  ),
                );
          }
        }
      });
    } catch (e) {
      debugPrint("Mid-Plan Optimization Error: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
