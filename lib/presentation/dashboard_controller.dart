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

    // 1. FIX: Added the `!profile.isPro` check.
    // Pro users bypass this block entirely, even if credits are 0!
    if (!profile.isPro && profile.aiCredits <= 0) {
      state = AsyncValue.error(
        Exception(
          "You've used all your free AI generations! Upgrade to Pro for unlimited AI workouts.",
        ),
        StackTrace.current,
      );
      return;
    }

    // Set state to loading so the UI shows the spinner
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(aiRepositoryProvider);
        final currentLocale = profile.appLocale;

        await repository.generateWithTools(prompt, currentLocale, profile);

        // 2. FIX: Burn a credit upon successful generation!
        // (Remember, our Notifier ignores this if they are Pro)
        await ref.read(userProfileProvider.notifier).useAiCredit();

        // Refresh the list from Drift
        return await ref
            .read(databaseProvider)
            .select(ref.read(databaseProvider).workouts)
            .get();
      } catch (e) {
        // 3. FIX: Intercept specific Quota/Server errors before the guard catches them
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
