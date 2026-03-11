import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/local/database.dart';
import '../repositories/providers.dart';

part 'dashboard_controller.g.dart';

@riverpod
class DashboardController extends _$DashboardController {
  @override
  Future<List<Workout>> build() async {
    return ref.watch(databaseProvider).select(ref.read(databaseProvider).workouts).get();
  }

  Future<void> generateWorkout(String prompt) async {
    // Set state to loading so the UI shows the spinner [cite: 54]
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(aiRepositoryProvider);

      // Trigger the Agentic Loop
      await repository.generateWithTools(prompt);

      // Refresh the list from Drift [cite: 20]
      return ref.read(databaseProvider).select(ref.read(databaseProvider).workouts).get();
    });
  }
}