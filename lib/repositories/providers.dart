import 'package:drift/drift.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:workout_minds/core/constants.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:workout_minds/services/workout_audio_handler.dart';
import 'ai_workout_repository.dart';

// The Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Updated Vertex AI Model Provider using AppConstants
final aiModelProvider = Provider<GenerativeModel>((ref) {
  return GenerativeModel(
    model: AppConstants.modelName,
    apiKey: AppConstants.geminiApiKey, // Using the constant key
    tools: workoutTools,
  );
});

// The AI Repository Provider
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

final weeklyStatsProvider = FutureProvider<List<FlSpot>>((ref) async {
  final db = ref.read(databaseProvider);
  final logs = await db.getWeeklyVolumeStats();

  if (logs.isEmpty) return [];

  List<FlSpot> spots = [];
  final today = DateTime.now();
  final cleanToday = DateTime(today.year, today.month, today.day); // Strip time

  // Create a 7-day flatline first (0 to 6)
  Map<int, double> dailyData = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

  for (var log in logs) {
    // FIX: Access the properties directly from the WorkoutLog object!
    final logDate = log.executedAt;
    final cleanLogDate = DateTime(logDate.year, logDate.month, logDate.day);

    final difference = cleanToday.difference(cleanLogDate).inDays;

    // Map it: 6 is today, 0 is 6 days ago.
    if (difference >= 0 && difference <= 6) {
      final xIndex = 6 - difference;
      // Add the volume to that day's total directly
      dailyData[xIndex] =
          (dailyData[xIndex] ?? 0) + (log.totalVolume).toDouble();
    }
  }

  dailyData.forEach((key, value) => spots.add(FlSpot(key.toDouble(), value)));
  return spots;
});
