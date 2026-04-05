import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:workout_minds/data/local/database.dart';

class AIPlanRepository {
  final GenerativeModel _model;
  final AppDatabase _db;

  AIPlanRepository(this._model, this._db);

  Future<int> generateAndSavePlan(String userPrompt) async {
    try {
      // 1. Ask Gemini for the 4-week blueprint
      final prompt =
          '''
      You are an elite AI personal trainer. 
      Create a structured workout plan based on this request: "$userPrompt".
      Ensure the weekly schedule includes rest days to allow for recovery.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception("AI returned an empty response.");
      }

      // 2. Parse the strict JSON
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
                      imageUrl: Value(exData['image_url']),
                      equipment: Value(exData['equipment']),
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
}
