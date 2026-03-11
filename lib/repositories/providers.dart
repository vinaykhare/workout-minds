import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:workout_minds/core/constants.dart';
import 'package:workout_minds/data/local/database.dart';
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
final workoutDetailsProvider = FutureProvider.family<List<TypedResult>, int>((ref, workoutId) {
  final db = ref.watch(databaseProvider);
  return db.getWorkoutDetails(workoutId);
});