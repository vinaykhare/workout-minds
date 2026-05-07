import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workout_minds/repositories/preferences_provider.dart';
import '../data/local/database.dart';
import '../repositories/providers.dart';

part 'dashboard_controller.g.dart';

@riverpod
class DashboardController extends _$DashboardController {
  @override
  Future<List<Workout>> build() async {
    return ref
        .watch(databaseProvider)
        .select(ref.read(databaseProvider).workouts)
        .get();
  }

  Future<void> generateWorkout(String prompt) async {
    final profile = ref.read(userProfileProvider);

    // Set state to loading so the UI shows the spinner
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(aiRepositoryProvider);
        final currentLocale = profile.appLocale;

        // The repository handles the Firestore credit deduction securely!
        await repository.generateWithTools(prompt, currentLocale, profile);

        // --- FIRE BACKGROUND SYNC AFTER SINGLE WORKOUT ---
        if (profile.isAutoSyncEnabled) {
          final profileJsonString = jsonEncode(profile.toJson());
          ref.read(driveSyncProvider).backupToCloud(profileJsonString).ignore();
        }

        // Refresh the list from Drift
        return await ref
            .read(databaseProvider)
            .select(ref.read(databaseProvider).workouts)
            .get();
      } catch (e) {
        // Intercept specific Quota/Server errors before the guard catches them
        String errorMessage = e.toString();
        if (errorMessage.contains('429') ||
            errorMessage.contains('exhausted') ||
            errorMessage.contains('503')) {
          throw Exception(
            "The AI servers are currently extremely busy. Please try again in a minute!",
          );
        }
        rethrow; // Pass any other standard errors back out to the guard
      }
    });
  }
}
