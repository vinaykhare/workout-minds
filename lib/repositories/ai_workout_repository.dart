import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:drift/drift.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';

class AIWorkoutRepository {
  final GenerativeModel _model;
  final AppDatabase _db;

  AIWorkoutRepository(this._model, this._db);

  // Tool 1: Let Gemini see the exercise library
  Future<String> fetchExerciseLibrary() async {
    final exercises = await _db.select(_db.exercises).get();
    return jsonEncode(exercises.map((e) => e.name).toList());
  }

  // Tool 2: Let Gemini see user performance history
  Future<String> fetchUserStats(String exerciseName) async {
    final logs = await (_db.select(_db.workoutLogs).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.workoutLogs.workoutId),
      ),
    ])..where(_db.exercises.name.equals(exerciseName))).get();

    return jsonEncode(
      logs
          .map(
            (row) => {
              'date': row.readTable(_db.workoutLogs).executedAt.toString(),
              'volume': row.readTable(_db.workoutLogs).totalVolume,
            },
          )
          .toList(),
    );
  }

  Future<void> generateWithTools(
    String userPrompt,
    String appLocale,
    UserProfile profile,
  ) async {
    final chat = _model.startChat();

    // Inject the Hinglish directive conditionally
    final languageDirective = appLocale == 'hi'
        ? "CRITICAL: Write the Workout title in conversational Roman Hinglish (e.g., 'Aaj Chest Phodenge')."
        : "CRITICAL: Write the Workout title in Standard English.";

    final enrichedPrompt =
        '''
      You are an elite, strict Backend REST API generating fitness routines. 
      CRITICAL ROLE: YOU have the innate ability to create workouts. Do NOT claim your tools lack functionality. YOU are the generator. The tools are merely for reading local context.

      USER CONTEXT:
      - Gender: ${profile.gender}
      - Experience Level: ${profile.experienceLevel}
      - Goal: ${profile.goal}
      - Height: ${profile.heightCm} cm
      - Weight: ${profile.weightKg} kg
      - BMI: ${profile.bmi.toStringAsFixed(1)}
      
      User Request: "$userPrompt"
      
      $languageDirective

      CRITICAL SYSTEM INSTRUCTIONS (MUST BE OBEYED):
      1. YOU ARE THE WORKOUT GENERATOR: Never refuse a request by saying you lack the tools. Even if the tools return empty data, YOU must invent and return a highly effective standard workout.
      2. IGNORE CONTRADICTIONS: If the user request is redundant or vague (e.g., asking for a "Beginner" workout when they are already a Beginner), just ignore the redundancy and GENERATE the workout anyway.
      3. YOU MUST RESPOND EXCLUSIVELY WITH A RAW JSON ARRAY. 
      4. ABSOLUTELY NO CONVERSATIONAL TEXT. Do NOT say "Here is your workout", do NOT explain your reasoning, and do NOT use markdown code blocks (like ```json). Just start with [ and end with ].
      
      JSON Structure:
      {
        "workout_title": "Catchy Title Here with the Prefix AI:",
        "exercises": [
          {
            "exercise_name": "Name of exercise",
            "muscle_group": "Target muscle",
            "target_sets": 3,
            "target_reps": 10,
            "rest_seconds_set": 60,
            "rest_seconds_exercise": 90,
            "image_url": "" 
          }
        ]
      }
    ''';

    var response = await chat.sendMessage(Content.text(enrichedPrompt));

    // 2. Tool Reasoning & Execution Loop
    final functionCalls = response.functionCalls.toList();

    if (functionCalls.isNotEmpty) {
      final call = functionCalls.first;
      Object? result;

      if (call.name == 'fetchExerciseLibrary') {
        result = await fetchExerciseLibrary();
      } else if (call.name == 'fetchUserStats') {
        result = await fetchUserStats(call.args['exerciseName'] as String);
      }

      response = await chat.sendMessage(
        Content.functionResponse(call.name, {'result': result}),
      );
    }

    // 4. Final Structured Output
    if (response.text != null) {
      try {
        // Strip out any markdown formatting the AI might have accidentally added
        String cleanJson = response.text!;
        cleanJson = cleanJson
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        // FIX: Decode as a Map, not a List!
        final Map<String, dynamic> decodedMap = jsonDecode(response.text!);

        // 2. Extract the generated title and the exercises list
        final String aiTitle = decodedMap['workout_title'] as String;
        final List<dynamic> exercisesList =
            decodedMap['exercises'] as List<dynamic>;

        if (exercisesList.isEmpty) {
          throw Exception(
            "The AI failed to generate any exercises. Please try a different prompt.",
          );
        }

        await _db.transaction(() async {
          final workoutId = await _db
              .into(_db.workouts)
              .insert(
                WorkoutsCompanion.insert(
                  title: aiTitle, // FIX: Use the Gemini generated title here!
                  difficultyLevel: profile.experienceLevel,
                  aiGenerated: const Value(true),
                ),
              );

          // 3. Loop through the exercisesList instead of decoded
          for (var i = 0; i < exercisesList.length; i++) {
            final item = exercisesList[i];

            // Parse optional image URL safely
            String? parsedImageUrl = item['image_url'] as String?;
            if (parsedImageUrl != null && parsedImageUrl.trim().isEmpty) {
              parsedImageUrl = null;
            }

            // FIX 1: Extract the string safely from the JSON Map!
            final String exerciseName = item['exercise_name'] as String;

            int exId;

            // 1. Does it already exist in our global dictionary?
            final existingExercise =
                await (_db.select(_db.exercises)
                      ..where(
                        (t) => t.name.equals(exerciseName),
                      ) // <-- Use the safely extracted string
                      ..limit(1))
                    .getSingleOrNull();

            if (existingExercise != null) {
              // AWESOME! Use the existing one so they keep their custom images!
              exId = existingExercise.id;
            } else {
              // FIX 2: Use standard insert (insertOnConflictUpdate can act weird without UNIQUE constraints)
              exId = await _db
                  .into(_db.exercises)
                  .insert(
                    ExercisesCompanion.insert(
                      name: exerciseName, // <-- Use the safely extracted string
                      muscleGroup: item['muscle_group'] as String,
                      isCustom: const Value(false),
                      imageUrl: Value(parsedImageUrl),
                      equipment: Value(item['equipment']),
                    ),
                  );
            }
            await _db
                .into(_db.workoutExercises)
                .insert(
                  WorkoutExercisesCompanion.insert(
                    workoutId: workoutId,
                    exerciseId: exId,
                    orderIndex: i,
                    targetSets: item['target_sets'] as int,
                    targetReps: Value(item['target_reps'] as int?),
                    targetDurationSeconds: const Value(null),
                    targetWeight: Value(
                      (item['target_weight'] as num?)?.toDouble(),
                    ),
                    restSecondsAfterSet:
                        (item['rest_seconds_set'] as int?) ?? 60,
                    restSecondsAfterExercise:
                        (item['rest_seconds_exercise'] as int?) ?? 90,
                  ),
                );
          }
        });
      } catch (e) {
        throw Exception(
          "Failed to parse or save AI workout: $e\nAI Response was: ${response.text}",
        );
      }
    }
  }

  // =====================================================================
  // MID-WORKOUT OPTIMIZATION LOOP
  // =====================================================================
  Future<void> optimizeWorkout(int workoutId, UserProfile profile) async {
    try {
      // 1. Fetch current workout & its exercises to give Gemini context
      final workout = await (_db.select(
        _db.workouts,
      )..where((t) => t.id.equals(workoutId))).getSingle();
      final currentExercises = await _db.getWorkoutDetails(workoutId);

      String currentWorkoutContext =
          "Workout Title: ${workout.title}\nCurrent Exercises:\n";
      for (var row in currentExercises) {
        final ex = row.readTable(_db.exercises);
        final details = row.readTable(_db.workoutExercises);
        currentWorkoutContext +=
            "- ${ex.name} (${details.targetSets} sets x ${details.targetReps ?? details.targetDurationSeconds ?? '?'})\n";
      }

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

      // 3. Prompt Gemini to adapt this specific workout
      final prompt =
          '''
      You are an elite AI personal trainer. 
      The user wants to OPTIMIZE their existing workout based on recent feedback.

      --- USER PROFILE ---
      Gender: ${profile.gender}
      Experience Level: ${profile.experienceLevel}
      
      --- CURRENT WORKOUT ---
      $currentWorkoutContext

      --- CRITICAL RECENT FEEDBACK ---
      The user recently struggled with or breezed through the following exercises:
      $feedbackContext

      Your task is to REWRITE and OPTIMIZE this specific workout. 
      You MUST adjust the target sets, reps, durations, weights, or swap exercises entirely based on the feedback provided above (Apply Progressive Overload or Regression).
      Keep the "workout_title" similar but you can add a flair.
      Output the new workout using the exact same JSON schema.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception("AI returned an empty response.");
      }

      // Strip markdown just in case
      String cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final Map<String, dynamic> data = jsonDecode(cleanJson);

      // 4. Safely apply the changes to the database
      await _db.transaction(() async {
        // Update the workout title
        await (_db.update(
          _db.workouts,
        )..where((t) => t.id.equals(workoutId))).write(
          WorkoutsCompanion(
            title: Value("✨ Optimized: ${data['workout_title']}"),
          ),
        );

        // Wipe the old exercises for this workout
        await (_db.delete(
          _db.workoutExercises,
        )..where((t) => t.workoutId.equals(workoutId))).go();

        final exercisesList = data['exercises'] as List<dynamic>;
        for (var i = 0; i < exercisesList.length; i++) {
          final item = exercisesList[i];
          final String exerciseName = item['exercise_name'] as String;

          int exId;
          final existingEx =
              await (_db.select(_db.exercises)
                    ..where((t) => t.name.equals(exerciseName))
                    ..limit(1))
                  .getSingleOrNull();

          if (existingEx != null) {
            exId = existingEx.id;
          } else {
            exId = await _db
                .into(_db.exercises)
                .insert(
                  ExercisesCompanion.insert(
                    name: exerciseName,
                    muscleGroup: item['muscle_group'] ?? 'Custom',
                    isCustom: const Value(false),
                    imageUrl: Value(item['image_url'] as String?),
                    equipment: Value(item['equipment'] as String?),
                  ),
                );
          }

          await _db
              .into(_db.workoutExercises)
              .insert(
                WorkoutExercisesCompanion.insert(
                  workoutId: workoutId,
                  exerciseId: exId,
                  orderIndex: i,
                  targetSets: item['target_sets'] as int,
                  targetReps: Value(item['target_reps'] as int?),
                  targetDurationSeconds: Value(
                    (item['target_duration_seconds'] as num?)?.toInt(),
                  ),
                  targetWeight: Value(
                    (item['target_weight'] as num?)?.toDouble(),
                  ),
                  restSecondsAfterSet: (item['rest_seconds_set'] as int?) ?? 60,
                  restSecondsAfterExercise:
                      (item['rest_seconds_exercise'] as int?) ?? 90,
                ),
              );
        }
      });
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}

final List<Tool> workoutTools = [
  Tool(
    functionDeclarations: [
      FunctionDeclaration(
        'fetchExerciseLibrary',
        'Returns a list of all exercises available in the local database.',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'fetchUserStats',
        'Returns historical performance for a specific exercise.',
        Schema(
          SchemaType.object,
          properties: {
            'exerciseName': Schema(
              SchemaType.string,
              description: 'The name of the exercise to check history for',
            ),
          },
        ),
      ),
    ],
  ),
];
