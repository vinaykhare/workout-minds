import 'package:drift/drift.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import 'package:workout_minds/services/drive_sync_service.dart';
import 'package:workout_minds/services/workout_audio_handler.dart';
import 'ai_workout_repository.dart';

// The Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Put this provider near your databaseProvider
final driveSyncProvider = Provider<DriveSyncService>((ref) {
  return DriveSyncService();
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

final audioHandlerProvider = Provider<WorkoutAudioHandler>((ref) {
  throw UnimplementedError(
    'audioHandlerProvider must be overridden in main.dart',
  );
});

// FIX: Now tracks Consistency (count) instead of Weight Volume
final weeklyStatsProvider = FutureProvider<List<FlSpot>>((ref) async {
  final db = ref.read(databaseProvider);
  final logs = await db.getWeeklyVolumeStats();

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
      // Adds 1 to the daily count instead of volume
      dailyData[xIndex] = (dailyData[xIndex] ?? 0) + 1;
    }
  }

  dailyData.forEach((key, value) => spots.add(FlSpot(key.toDouble(), value)));
  return spots;
});

// FIX: Updated to use TypedResult so we get both the Log and the Workout Title
final recentWorkoutsProvider = FutureProvider<List<TypedResult>>((ref) async {
  final db = ref.read(databaseProvider);
  return await db.getRecentWorkoutLogsWithTitles(limit: 10);
});
