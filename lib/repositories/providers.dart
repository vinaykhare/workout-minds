import 'package:drift/drift.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/ai_plan_repository.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/services/drive_sync_service.dart';
import 'package:workout_minds/services/workout_audio_handler.dart';
import 'package:workout_minds/services/workout_share_service.dart';
import 'ai_workout_repository.dart';

// The Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// FIX 1: Pass the active database into the Sync Service!
final driveSyncProvider = Provider<DriveSyncService>((ref) {
  final db = ref.read(databaseProvider);
  return DriveSyncService(db);
});

// Updated Vertex AI Model Provider using AppConstants
// --- YOUR UPDATED PROVIDERS ---

final aiModelProvider = Provider<GenerativeModel>((ref) {
  final profile = ref.watch(userProfileProvider);

  final defaultDevKey = dotenv.env['GEMINI_API_KEY'] ?? 'MISSING_KEY';
  final defaultModelName = dotenv.env['MODEL_NAME'] ?? 'gemini-2.5-flash-lite';

  final activeApiKey = (profile.isPro && profile.customApiKey.isNotEmpty)
      ? profile.customApiKey
      : defaultDevKey;

  final activeModelName = (profile.isPro && profile.customModelName.isNotEmpty)
      ? profile.customModelName
      : defaultModelName;

  // THE SILVER BULLET: This forces the API to strictly output JSON
  // It completely eliminates conversational text and format errors.
  // THE SILVER BULLET: Dynamic Title + Strict Array
  final generationConfig = GenerationConfig(
    responseMimeType: 'application/json',
    responseSchema: Schema.object(
      properties: {
        "workout_title": Schema.string(
          description:
              "A short, catchy, highly motivating title for this specific workout.",
        ),
        "exercises": Schema.array(
          description: "A list of at least 4 fitness exercises.",
          items: Schema.object(
            properties: {
              "exercise_name": Schema.string(),
              "muscle_group": Schema.string(),
              "equipment": Schema.string(
                description: "E.g., Barbell, Dumbbell, Machine, Bodyweight",
              ),
              "target_weight": Schema.number(
                description: "Suggested weight in kg/lbs, or 0 if bodyweight",
              ),
              "target_sets": Schema.integer(),
              "target_reps": Schema.integer(),
              "rest_seconds_set": Schema.integer(),
              "rest_seconds_exercise": Schema.integer(),
              "image_url": Schema.string(),
            },
            requiredProperties: [
              "exercise_name",
              "muscle_group",
              "target_sets",
              "target_reps",
              "rest_seconds_set",
              "rest_seconds_exercise",
            ],
          ),
        ),
      },
      requiredProperties: ["workout_title", "exercises"],
    ),
  );

  return GenerativeModel(
    model: activeModelName,
    apiKey: activeApiKey,
    // tools: workoutTools,
    generationConfig: generationConfig, // Inject the strict schema here!
  );
});

// ============================================================================
// THE NEW "PLAN" ARCHITECT: Forces Gemini to output a structured weekly cycle
// ============================================================================
final aiPlanModelProvider = Provider<GenerativeModel>((ref) {
  final profile = ref.watch(userProfileProvider);

  final defaultDevKey = dotenv.env['GEMINI_API_KEY'] ?? 'MISSING_KEY';
  // Note: For complex multi-layered JSON like this, it is highly recommended
  // to use 'gemini-2.5-flash' instead of 'lite' if you find it struggling!
  final defaultModelName = dotenv.env['MODEL_NAME'] ?? 'gemini-2.5-flash-lite';

  final activeApiKey = (profile.isPro && profile.customApiKey.isNotEmpty)
      ? profile.customApiKey
      : defaultDevKey;

  final activeModelName = (profile.isPro && profile.customModelName.isNotEmpty)
      ? profile.customModelName
      : defaultModelName;

  final planSchema = Schema.object(
    properties: {
      "plan_title": Schema.string(
        description: "A catchy, motivating title for the program.",
      ),
      "plan_description": Schema.string(),
      "plan_goal": Schema.string(),
      "total_weeks": Schema.integer(
        description: "The duration of the plan (e.g., 4, 6, or 8 weeks).",
      ),

      // 1. THE WORKOUT DICTIONARY
      "unique_workouts": Schema.array(
        description: "A list of 3 to 5 unique workouts that make up this plan.",
        items: Schema.object(
          properties: {
            "workout_title": Schema.string(
              description: "Exact title to be referenced in the schedule.",
            ),
            "difficulty_level": Schema.string(),
            "exercises": Schema.array(
              items: Schema.object(
                properties: {
                  "exercise_name": Schema.string(),
                  "muscle_group": Schema.string(),
                  "equipment": Schema.string(
                    description: "E.g., Barbell, Dumbbell, Machine, Bodyweight",
                  ),
                  "target_weight": Schema.number(
                    description:
                        "Suggested weight in kg/lbs, or 0 if bodyweight",
                  ),
                  "target_sets": Schema.integer(),
                  "target_reps": Schema.integer(),
                  "target_duration_seconds": Schema.integer(),
                  "rest_seconds_set": Schema.integer(),
                  "rest_seconds_exercise": Schema.integer(),
                  "image_url": Schema.string(),
                },
                requiredProperties: [
                  "exercise_name",
                  "muscle_group",
                  "target_sets",
                  "rest_seconds_set",
                  "rest_seconds_exercise",
                ],
              ),
            ),
          },
          requiredProperties: [
            "workout_title",
            "difficulty_level",
            "exercises",
          ],
        ),
      ),

      // 2. THE WEEKLY SCHEDULE
      "weekly_schedule": Schema.array(
        description: "Exactly 7 days representing a standard repeating week.",
        items: Schema.object(
          properties: {
            "day_number": Schema.integer(description: "Day 1 through 7"),
            "workout_title": Schema.string(
              description:
                  "Must perfectly match a title in unique_workouts, or be exactly 'REST'.",
            ),
            "notes": Schema.string(
              description:
                  "Brief tip, e.g., 'Active recovery, walk 10k steps'.",
            ),
          },
          requiredProperties: ["day_number", "workout_title"],
        ),
      ),
    },
    requiredProperties: [
      "plan_title",
      "plan_description",
      "total_weeks",
      "unique_workouts",
      "weekly_schedule",
    ],
  );

  final generationConfig = GenerationConfig(
    responseMimeType: 'application/json',
    responseSchema: planSchema,
  );

  return GenerativeModel(
    model: activeModelName,
    apiKey: activeApiKey,
    generationConfig: generationConfig,
  );
});

final aiPlanRepositoryProvider = Provider<AIPlanRepository>((ref) {
  final model = ref.watch(aiPlanModelProvider);
  final db = ref.watch(databaseProvider);
  return AIPlanRepository(model, db);
});

final aiRepositoryProvider = Provider<AIWorkoutRepository>((ref) {
  final model = ref.watch(aiModelProvider);
  final db = ref.watch(databaseProvider);
  return AIWorkoutRepository(model, db);
});

// Fetches the joined exercise details for a given workout ID
final workoutDetailsProvider = StreamProvider.family<List<TypedResult>, int>((
  ref,
  workoutId,
) {
  return ref.watch(databaseProvider).getWorkoutDetailsStream(workoutId);
});

// FIX: Using .watch() turns this into a live stream.
// Any insert, update, or delete in the DB will instantly redraw the Dashboard.
final workoutsStreamProvider = StreamProvider<List<Workout>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.workouts,
  )..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();
});

// Streams all Workout Plans live from the database
final plansStreamProvider = StreamProvider<List<WorkoutPlan>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.workoutPlans,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
});

final audioHandlerProvider = Provider<WorkoutAudioHandler>((ref) {
  throw UnimplementedError(
    'audioHandlerProvider must be overridden in main.dart',
  );
});

// --- FIX 1: DASHBOARD SEARCH STATE ---
final dashboardSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredWorkoutsStreamProvider = StreamProvider<List<Workout>>((ref) {
  final query = ref.watch(dashboardSearchQueryProvider);
  return ref.watch(databaseProvider).watchFilteredWorkouts(query);
});

// --- FIX 2: LIVE UPDATING DASHBOARD WIDGETS ---
final weeklyStatsProvider = StreamProvider<List<FlSpot>>((ref) {
  return ref.watch(databaseProvider).watchWeeklyVolumeStats().map((logs) {
    if (logs.isEmpty) return [];

    List<FlSpot> spots = [];
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    Map<int, double> dailyData = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

    for (var log in logs) {
      final logDate = log.executedAt;
      final cleanLogDate = DateTime(logDate.year, logDate.month, logDate.day);
      final difference = cleanToday.difference(cleanLogDate).inDays;

      if (difference >= 0 && difference <= 6) {
        final xIndex = 6 - difference;
        dailyData[xIndex] = (dailyData[xIndex] ?? 0) + 1;
      }
    }

    dailyData.forEach((key, value) => spots.add(FlSpot(key.toDouble(), value)));
    return spots;
  });
});

final recentWorkoutsProvider = StreamProvider<List<TypedResult>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchRecentWorkoutLogsWithTitles(limit: 10);
});

final workoutShareProvider = Provider<WorkoutShareService>((ref) {
  final db = ref.read(databaseProvider);
  return WorkoutShareService(db);
});

// --- NEW: A global provider to hold files that arrive while the app is waking up! ---
final pendingImportProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

// --- PLAN UI PROVIDERS ---
final planDetailsProvider = FutureProvider.family<WorkoutPlan, int>((
  ref,
  planId,
) {
  return ref.watch(databaseProvider).getPlan(planId);
});

final planScheduleProvider = FutureProvider.family<List<TypedResult>, int>((
  ref,
  planId,
) {
  return ref.watch(databaseProvider).getPlanSchedule(planId);
});
