import 'package:flutter_riverpod/flutter_riverpod.dart';

class DraftExercise {
  String name;
  int sets;
  int reps;
  int? durationSeconds;
  bool isDuration;
  int restSecondsSet;
  int restSecondsExercise;
  String? localImagePath;
  String? imageUrl;
  final String? equipment;
  final double? targetWeight;

  DraftExercise({
    required this.name,
    this.sets = 3,
    this.reps = 10,
    this.durationSeconds = 30,
    this.isDuration = false,
    this.restSecondsSet = 60,
    this.restSecondsExercise = 90,
    this.localImagePath,
    this.imageUrl,
    this.equipment,
    this.targetWeight,
  });

  DraftExercise copyWith({
    String? name,
    int? sets,
    int? reps,
    int? durationSeconds, // Left as nullable
    bool? isDuration, // FIX 1: Must be nullable (bool?) without a default
    int? restSecondsSet,
    int? restSecondsExercise,
    String? localImagePath,
    String? imageUrl,
    bool clearLocalImage = false,
    bool clearImageUrl = false,
    String? equipment,
    double? targetWeight,
    bool clearEquipment = false,
    bool clearTargetWeight = false,
  }) {
    return DraftExercise(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      // FIX 2: Actually use the passed-in parameters!
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isDuration: isDuration ?? this.isDuration,
      restSecondsSet: restSecondsSet ?? this.restSecondsSet,
      restSecondsExercise: restSecondsExercise ?? this.restSecondsExercise,
      localImagePath: clearLocalImage
          ? null
          : (localImagePath ?? this.localImagePath),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      equipment: clearEquipment ? null : (equipment ?? this.equipment),
      targetWeight: clearTargetWeight
          ? null
          : (targetWeight ?? this.targetWeight),
    );
  }
}

class WorkoutDraftNotifier extends Notifier<List<DraftExercise>> {
  @override
  List<DraftExercise> build() => [];

  void loadExercises(List<DraftExercise> existing) => state = existing;
  void addExercise(DraftExercise exercise) => state = [...state, exercise];

  void updateExercise(int index, DraftExercise updated) {
    final newState = List<DraftExercise>.from(state);
    newState[index] = updated;
    state = newState;
  }

  void removeExercise(int index) {
    final newState = List<DraftExercise>.from(state);
    newState.removeAt(index);
    state = newState;
  }

  void insertExercise(int index, DraftExercise exercise) {
    final newState = List<DraftExercise>.from(state);
    newState.insert(index, exercise);
    state = newState;
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final newState = List<DraftExercise>.from(state);
    final item = newState.removeAt(oldIndex);
    newState.insert(newIndex, item);
    state = newState;
  }
}

final workoutDraftProvider =
    NotifierProvider<WorkoutDraftNotifier, List<DraftExercise>>(() {
      return WorkoutDraftNotifier();
    });
