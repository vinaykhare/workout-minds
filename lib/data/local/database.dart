import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// 1. Exercises Table: The global library of movements [cite: 17]
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get instructionUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

// 2. Workouts Table: Metadata for training sessions [cite: 17]
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get difficultyLevel => text()(); // e.g., Beginner, Advanced
  BoolColumn get aiGenerated => boolean().withDefault(const Constant(false))();
}

// 3. WorkoutExercises: Junction table for the many-to-many relationship
class WorkoutExercises extends Table {
  IntColumn get workoutId => integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer()();
  IntColumn get targetReps => integer()();
}

// 4. WorkoutLogs: Historical records of completed sessions [cite: 17]
class WorkoutLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  DateTimeColumn get executedAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalVolume => real()(); // weight x reps [cite: 17]
  IntColumn get durationMinutes => integer()();
}

@DriftDatabase(tables: [Exercises, Workouts, WorkoutExercises, WorkoutLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // AI Tool Call Helper: Fetch historical stats for a specific exercise [cite: 32, 33]
  // Change OrderMode.desc to OrderingMode.desc
  Future<List<WorkoutLog>> getLogsForExercise(int exerciseId) {
    return (select(workoutLogs)
      ..where((tbl) => tbl.workoutId.equals(exerciseId))
      ..orderBy([
            (t) => OrderingTerm(expression: t.executedAt, mode: OrderingMode.desc)
      ]))
        .get();
  }

  // Fetches exercises for a specific workout, ordered by their sequence
  Future<List<TypedResult>> getWorkoutDetails(int workoutId) {
    return (select(workoutExercises).join([
      innerJoin(exercises, exercises.id.equalsExp(workoutExercises.exerciseId))
    ])
      ..where(workoutExercises.workoutId.equals(workoutId))
      ..orderBy([OrderingTerm(expression: workoutExercises.orderIndex, mode: OrderingMode.asc)])).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_minds.sqlite'));
    return NativeDatabase(file);
  });
}