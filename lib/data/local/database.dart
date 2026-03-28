import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// 1. Exercises Table: The global library of movements [cite: 17]
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get instructionUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get imageUrl =>
      text().nullable()(); // For AI/Internet fetched images
  TextColumn get localImagePath =>
      text().nullable()(); // For user-selected gallery images
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
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();

  // Reps can now be nullable if it's a duration-based exercise
  IntColumn get targetSets => integer()();
  IntColumn get targetReps => integer().nullable()();

  // NEW: Support for timed exercises (e.g. 30 seconds of jumping jacks)
  IntColumn get targetDurationSeconds => integer().nullable()();

  IntColumn get restSecondsAfterSet => integer()();
  IntColumn get restSecondsAfterExercise => integer()();

  // @override
  // Set<Column> get primaryKey => {workoutId, exerciseId, orderIndex};
}

// 4. WorkoutLogs: Historical records of completed sessions [cite: 17]
class WorkoutLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  DateTimeColumn get executedAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalVolume => real()(); // weight x reps [cite: 17]
  IntColumn get durationMinutes => integer()();
}

// 5. ExerciseLogs: Granular tracking of individual sets performed
class ExerciseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Links this specific set to the overall workout session.
  // Cascade delete ensures if the user deletes the workout record, the set records vanish too.
  IntColumn get workoutLogId =>
      integer().references(WorkoutLogs, #id, onDelete: KeyAction.cascade)();

  // Links to the global exercise dictionary (e.g., "Bench Press")
  IntColumn get exerciseId => integer().references(Exercises, #id)();

  // The actual execution metrics
  IntColumn get setIndex => integer()(); // 1st set, 2nd set, etc.
  RealColumn get weight =>
      real()(); // Real column to support decimals like 12.5 kg
  IntColumn get reps => integer()();

  // Future-proofing fields
  IntColumn get rpe =>
      integer().nullable()(); // Rate of Perceived Exertion (1-10 scale)
  TextColumn get notes =>
      text().nullable()(); // E.g., "Felt a pinch in shoulder"
}

@DriftDatabase(
  tables: [Exercises, Workouts, WorkoutExercises, WorkoutLogs, ExerciseLogs],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // AI Tool Call Helper: Fetch historical stats for a specific exercise [cite: 32, 33]
  // Change OrderMode.desc to OrderingMode.desc
  // Future<List<WorkoutLog>> getLogsForExercise(int exerciseId) {
  //   return (select(workoutLogs)
  //         ..where((tbl) => tbl.workoutId.equals(exerciseId))
  //         ..orderBy([
  //           (t) =>
  //               OrderingTerm(expression: t.executedAt, mode: OrderingMode.desc),
  //         ]))
  //       .get();
  // }

  // Fetches the set-by-set history for a specific exercise (e.g., to plot a Bench Press progress chart)
  Future<List<ExerciseLog>> getHistoryForExercise(int targetExerciseId) {
    return (select(exerciseLogs)
          ..where((tbl) => tbl.exerciseId.equals(targetExerciseId))
          // We can't order by date directly here since date is in WorkoutLogs.
          // For now, ordering by the log ID inherently sorts them chronologically.
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .get();
  }

  // Fetches the historical completion logs for a specific Workout
  Future<List<WorkoutLog>> getLogsForWorkout(int workoutId) {
    return (select(workoutLogs)
          ..where((tbl) => tbl.workoutId.equals(workoutId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.executedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  // Fetches exercises for a specific workout, ordered by their sequence
  Future<List<TypedResult>> getWorkoutDetails(int workoutId) {
    return (select(workoutExercises).join([
            innerJoin(
              exercises,
              exercises.id.equalsExp(workoutExercises.exerciseId),
            ),
          ])
          ..where(workoutExercises.workoutId.equals(workoutId))
          ..orderBy([
            OrderingTerm(
              expression: workoutExercises.orderIndex,
              mode: OrderingMode.asc,
            ),
          ]))
        .get();
  }

  Stream<List<TypedResult>> getWorkoutDetailsStream(int workoutId) {
    return (select(workoutExercises).join([
            innerJoin(
              exercises,
              exercises.id.equalsExp(workoutExercises.exerciseId),
            ),
          ])
          ..where(workoutExercises.workoutId.equals(workoutId))
          ..orderBy([OrderingTerm.asc(workoutExercises.orderIndex)]))
        .watch();
  }

  // Fetches the most recent logs globally AND grabs the workout title!
  Future<List<TypedResult>> getRecentWorkoutLogsWithTitles({int limit = 10}) {
    return (select(workoutLogs).join([
            innerJoin(workouts, workouts.id.equalsExp(workoutLogs.workoutId)),
          ])
          ..orderBy([OrderingTerm.desc(workoutLogs.executedAt)])
          ..limit(limit))
        .get();
  }

  // Deletes a workout and all its linked junction records automatically
  Future<void> deleteWorkout(int workoutId) {
    return (delete(workouts)..where((t) => t.id.equals(workoutId))).go();
  }

  // 1. Save the workout when completed
  // 1. Save the workout when completed
  Future<void> logWorkoutCompletion(int workoutId, int calculatedVolume) async {
    await into(workoutLogs).insert(
      WorkoutLogsCompanion(
        workoutId: Value(workoutId),
        executedAt: Value(DateTime.now()),
        // FIX: Convert the int to a double to match your database schema
        totalVolume: Value(calculatedVolume.toDouble()),
        durationMinutes: const Value(0),
      ),
    );
  }

  // 2. Fetch data for the last 7 days
  Future<List<WorkoutLog>> getWeeklyVolumeStats() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 6));
    // Simple fetch: let Dart handle the math in the provider
    return await (select(
      workoutLogs,
    )..where((t) => t.executedAt.isBiggerOrEqualValue(sevenDaysAgo))).get();
  }

  // --- DANGER ZONE: Factory Reset ---
  Future<void> wipeAllUserData() async {
    // Delete all historical logs and custom workouts
    await delete(exerciseLogs).go();
    await delete(workoutLogs).go();
    await delete(workoutExercises).go();
    await delete(workouts).go();
    // Note: We leave the 'exercises' table alone so the global library remains intact!
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_minds.sqlite'));

    // 1. THE ANDROID FIX: Forces the OS to locate the bundled libsqlite3.so
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // 2. SANDBOX FIX: Tell SQLite exactly where it is allowed to write temporary files
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    // 3. PERFORMANCE FIX: Open the database in a background isolate
    // This prevents the UI from freezing when the AI inserts massive workout JSONs!
    return NativeDatabase.createInBackground(file);
  });
}
