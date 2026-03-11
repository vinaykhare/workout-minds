import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:drift/drift.dart';
import 'package:workout_minds/data/local/database.dart';

class AIWorkoutRepository {
  final GenerativeModel _model;
  final AppDatabase _db;

  AIWorkoutRepository(this._model, this._db);

  // --- TOOLS (Agent Skills) ---

  // Tool 1: Let Gemini see the exercise library
  Future<String> fetchExerciseLibrary() async {
    final exercises = await _db.select(_db.exercises).get();
    return jsonEncode(exercises.map((e) => e.name).toList());
  }

  // Tool 2: Let Gemini see user performance history
  Future<String> fetchUserStats(String exerciseName) async {
    final logs = await (_db.select(_db.workoutLogs).join([
      innerJoin(_db.exercises, _db.exercises.id.equalsExp(_db.workoutLogs.workoutId)),
    ])..where(_db.exercises.name.equals(exerciseName)))
        .get();

    return jsonEncode(logs.map((row) => {
      'date': row.readTable(_db.workoutLogs).executedAt.toString(),
      'volume': row.readTable(_db.workoutLogs).totalVolume,
    }).toList());
  }

  // --- THE AGENTIC LOOP ---

  Future<void> generateWithTools(String userPrompt) async {
    final chat = _model.startChat();

    // 1. Prompt Initiation with Strict Instructions
    final enrichedPrompt = '''
      You are an expert fitness coach. 
      User Request: "$userPrompt"
      
      CRITICAL INSTRUCTIONS:
      1. Use your tools to check the local exercise library or user stats if needed.
      2. If the local library is empty or lacks suitable exercises, YOU MUST INVENT appropriate standard exercises (e.g., "Bench Press", "Squats").
      3. Your final output MUST be ONLY a raw JSON array of objects. Do not include markdown blocks (```json), apologies, or conversational text.
      
      JSON Structure:
      [
        {
          "exercise_name": "Name of exercise",
          "muscle_group": "Target muscle",
          "target_sets": 3,
          "target_reps": 10
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

      // 3. Return local result to the Agent
      response = await chat.sendMessage(
          Content.functionResponse(call.name, {'result': result})
      );
    }

    // 4. Final Structured Output
    if (response.text != null) {
      try {
        String rawText = response.text!;

        // --- DEFENSIVE PARSING START ---
        // Find the first '[' and the last ']' in the AI's response
        int startIndex = rawText.indexOf('[');
        int endIndex = rawText.lastIndexOf(']');

        if (startIndex == -1 || endIndex == -1) {
          throw FormatException("Could not locate a JSON array in the AI response.");
        }

        // Extract strictly the JSON part
        String jsonString = rawText.substring(startIndex, endIndex + 1);
        final List<dynamic> decoded = jsonDecode(jsonString);
        // --- DEFENSIVE PARSING END ---

        await _db.transaction(() async {
          final workoutId = await _db.into(_db.workouts).insert(
            WorkoutsCompanion.insert(
              title: "AI Plan: $userPrompt",
              difficultyLevel: 'Intermediate',
              aiGenerated: const Value(true),
            ),
          );

          for (var i = 0; i < decoded.length; i++) {
            final item = decoded[i];

            final exId = await _db.into(_db.exercises).insertOnConflictUpdate(
              ExercisesCompanion.insert(
                name: item['exercise_name'],
                muscleGroup: item['muscle_group'],
              ),
            );

            await _db.into(_db.workoutExercises).insert(
              WorkoutExercisesCompanion.insert(
                workoutId: workoutId,
                exerciseId: exId,
                orderIndex: i,
                targetSets: item['target_sets'],
                targetReps: item['target_reps'],
              ),
            );
          }
        });
      } catch (e) {
        throw Exception("Failed to parse or save AI workout: $e\nAI Response was: ${response.text}");
      }
    }
  }
}

final List<Tool> workoutTools = [
  Tool(functionDeclarations: [
    FunctionDeclaration(
      'fetchExerciseLibrary',
      'Returns a list of all exercises available in the local database.',
      Schema(SchemaType.object, properties: {}),
    ),
    FunctionDeclaration(
      'fetchUserStats',
      'Returns historical performance for a specific exercise.',
      Schema(SchemaType.object, properties: {
        'exerciseName': Schema(SchemaType.string, description: 'The name of the exercise to check history for'),
      }),
    ),
  ])
];