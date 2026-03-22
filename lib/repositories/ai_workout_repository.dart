import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:drift/drift.dart';
import 'package:workout_minds/data/local/database.dart';

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

  Future<void> generateWithTools(String userPrompt, String appLocale) async {
    final chat = _model.startChat();

    // Inject the Hinglish directive conditionally
    final languageDirective = appLocale == 'hi'
        ? "CRITICAL: Write the Workout title in conversational Roman Hinglish (e.g., 'Aaj Chest Phodenge')."
        : "CRITICAL: Write the Workout title in Standard English.";

    // 1. Prompt Initiation with STRICT Updated JSON Schema
    // 1. Prompt Initiation with STRICT Updated JSON Schema
    // 1. Prompt Initiation with STRICT JSON API Persona
    // 1. Prompt Initiation with STRICT JSON API Persona & No-Refusal Clause
    final enrichedPrompt =
        '''
      You are a strict Backend REST API that generates fitness routines.
      User Request: "$userPrompt"
      
      $languageDirective

      CRITICAL INSTRUCTIONS:
      1. Use your tools to check the local exercise library. If it lacks suitable exercises, invent standard ones (like Bench Press, Squats, etc.).
      2. NEVER refuse a request or ask for clarification. If the user request is short or vague (like "chest day" or "workout"), just invent a highly effective standard workout that fits the theme.
      3. YOU MUST RESPOND EXCLUSIVELY WITH A RAW JSON ARRAY. 
      4. ABSOLUTELY NO CONVERSATIONAL TEXT. Do NOT say "Here is your workout" or "I am unable to generate".
      
      JSON Structure:
      [
        {
          "exercise_name": "Name of exercise",
          "muscle_group": "Target muscle",
          "target_sets": 3,
          "target_reps": 10,
          "rest_seconds_set": 60,
          "rest_seconds_exercise": 90,
          "image_url": "" // CRITICAL: ALWAYS leave this as an empty string. DO NOT guess, fabricate, or generate URLs under any circumstances.
        }
      ]
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
        String rawText = response.text!;

        int startIndex = rawText.indexOf('[');
        int endIndex = rawText.lastIndexOf(']');

        if (startIndex == -1 || endIndex == -1) {
          throw FormatException(
            "Could not locate a JSON array in the AI response.",
          );
        }

        String jsonString = rawText.substring(startIndex, endIndex + 1);
        final List<dynamic> decoded = jsonDecode(jsonString);

        await _db.transaction(() async {
          final workoutId = await _db
              .into(_db.workouts)
              .insert(
                WorkoutsCompanion.insert(
                  title: "AI Plan: $userPrompt",
                  difficultyLevel: 'Intermediate',
                  aiGenerated: const Value(true),
                ),
              );

          for (var i = 0; i < decoded.length; i++) {
            final item = decoded[i];

            // Parse optional image URL safely
            String? parsedImageUrl = item['image_url'] as String?;
            if (parsedImageUrl != null && parsedImageUrl.trim().isEmpty) {
              parsedImageUrl = null;
            }

            // FIX: Use standard constructor instead of .insert to bypass the 'id' quirk,
            // and explicitly cast the JSON dynamic values to Strings/Ints.
            final exId = await _db
                .into(_db.exercises)
                .insertOnConflictUpdate(
                  ExercisesCompanion(
                    name: Value(item['exercise_name'] as String),
                    muscleGroup: Value(item['muscle_group'] as String),
                    imageUrl: Value(parsedImageUrl),
                  ),
                );

            await _db
                .into(_db.workoutExercises)
                .insert(
                  WorkoutExercisesCompanion.insert(
                    // The clean insert is back!
                    workoutId: workoutId,
                    exerciseId: exId,
                    orderIndex: i,
                    targetSets: item['target_sets'] as int,
                    targetReps: Value(item['target_reps'] as int?),
                    targetDurationSeconds: const Value(null),
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
