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
    // Set state to loading so the UI shows the spinner [cite: 54]
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(aiRepositoryProvider);

      // Trigger the Agentic Loop
      final currentLocale = ref.read(userProfileProvider).appLocale;
      await repository.generateWithTools(prompt, currentLocale);

      // Refresh the list from Drift [cite: 20]
      return ref
          .read(databaseProvider)
          .select(ref.read(databaseProvider).workouts)
          .get();
    });
  }
}
