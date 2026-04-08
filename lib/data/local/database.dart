import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// 1. Exercises Table: The global library of movements
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get instructionUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get localImagePath => text().nullable()();
  TextColumn get instructions => text().nullable()(); // Added for Issue 4c
  TextColumn get equipment => text().nullable()();
}

// 2. Workouts Table: Metadata for training sessions (The "Floors")
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get difficultyLevel => text()();
  BoolColumn get aiGenerated => boolean().withDefault(const Constant(false))();
}

// 3. WorkoutExercises: Junction table
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();

  IntColumn get targetSets => integer()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetDurationSeconds => integer().nullable()();
  RealColumn get targetWeight => real().nullable()();
  IntColumn get restSecondsAfterSet => integer()();
  IntColumn get restSecondsAfterExercise => integer()();
}

// 4. WorkoutLogs: Historical records of completed sessions
class WorkoutLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  IntColumn get planId => integer().nullable().references(WorkoutPlans, #id)();
  DateTimeColumn get executedAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalVolume => real()();
  IntColumn get durationMinutes => integer()();
  TextColumn get executionFeedback => text().nullable()(); // Added for Issue 4d
}

// --- NEW: Track historical completions of entire plans! ---
class PlanLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(WorkoutPlans, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// Helper class to return the joined data to the UI cleanly
class PlanLogData {
  final PlanLog log;
  final WorkoutPlan plan;
  PlanLogData(this.log, this.plan);
}

// 5. ExerciseLogs: Granular tracking of individual sets performed
class ExerciseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutLogId =>
      integer().references(WorkoutLogs, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get setIndex => integer()();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  IntColumn get rpe => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

// ==========================================
// NEW TABLES: THE "UMBRELLA" PLAN STRUCTURE
// ==========================================

// 6. WorkoutPlans: The high-level program metadata
class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get goal => text().nullable()(); // e.g., "Fat Loss", "Muscle Gain"
  IntColumn get totalWeeks => integer().withDefault(const Constant(4))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

// 7. WorkoutPlanDays: Mapping workouts to specific days in the plan
class WorkoutPlanDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(WorkoutPlans, #id, onDelete: KeyAction.cascade)();

  // Represents the day sequence (e.g., Day 1, Day 2... Day 28)
  IntColumn get dayNumber => integer()();

  // A null workoutId represents a "Rest Day"
  // setNull ensures if a user deletes the underlying workout, the plan doesn't break!
  IntColumn get workoutId => integer().nullable().references(
    Workouts,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get notes => text().nullable()(); // e.g., "Focus on form today"
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(
  tables: [
    Exercises,
    Workouts,
    WorkoutExercises,
    WorkoutLogs,
    ExerciseLogs,
    WorkoutPlans,
    WorkoutPlanDays,
    PlanLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Bumped to version 3!
  @override
  int get schemaVersion => 1;

  // --- NEW: Toggle Day Completion ---
  Future<void> togglePlanDayCompletion(int planDayId, bool isCompleted) {
    return (update(workoutPlanDays)..where((t) => t.id.equals(planDayId)))
        .write(WorkoutPlanDaysCompanion(isCompleted: Value(isCompleted)));
  }

  // --- ALL EXISTING METHODS REMAIN UNCHANGED BELOW THIS LINE ---

  Future<List<ExerciseLog>> getHistoryForExercise(int targetExerciseId) {
    return (select(exerciseLogs)
          ..where((tbl) => tbl.exerciseId.equals(targetExerciseId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<WorkoutLog>> getLogsForWorkout(int workoutId) {
    return (select(workoutLogs)
          ..where((tbl) => tbl.workoutId.equals(workoutId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.executedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  // --- NEW: Fetch historical workout logs for a specific plan run ---
  Future<List<WorkoutLog>> getLogsForPlanInstance(
    int planId,
    DateTime start,
    DateTime end,
  ) {
    return (select(workoutLogs)
          ..where(
            (t) =>
                t.planId.equals(planId) &
                t.executedAt.isBiggerOrEqualValue(start) &
                t.executedAt.isSmallerOrEqualValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.executedAt)]))
        .get();
  }

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

  Future<List<TypedResult>> getRecentWorkoutLogsWithTitles({int limit = 10}) {
    return (select(workoutLogs).join([
            innerJoin(workouts, workouts.id.equalsExp(workoutLogs.workoutId)),
          ])
          ..orderBy([OrderingTerm.desc(workoutLogs.executedAt)])
          ..limit(limit))
        .get();
  }

  Future<void> deleteWorkout(int workoutId) {
    return (delete(workouts)..where((t) => t.id.equals(workoutId))).go();
  }

  Future<void> completePlanAndReset(int planId) async {
    await transaction(() async {
      // 1. Get the plan to find out when it started
      final plan = await (select(
        workoutPlans,
      )..where((t) => t.id.equals(planId))).getSingle();

      // 2. Create the historical log!
      await into(planLogs).insert(
        PlanLogsCompanion.insert(
          planId: planId,
          startedAt: plan.startDate ?? DateTime.now(),
          completedAt: Value(DateTime.now()),
        ),
      );

      // 3. Reset the plan to Day 1 so they can run it again
      await (update(workoutPlans)..where((t) => t.id.equals(planId))).write(
        const WorkoutPlansCompanion(
          startDate: Value(null),
          completedAt: Value(null),
        ),
      );

      await (update(workoutPlanDays)..where((t) => t.planId.equals(planId)))
          .write(const WorkoutPlanDaysCompanion(isCompleted: Value(false)));
    });
  }

  // Deletes a plan. (Cascade delete automatically wipes WorkoutPlanDays!)
  Future<void> deletePlan(int planId) {
    return (delete(workoutPlans)..where((t) => t.id.equals(planId))).go();
  }

  Future<void> logWorkoutCompletion(
    int workoutId,
    int calculatedVolume, {
    String? feedbackJson,
    int? planId,
  }) async {
    await into(workoutLogs).insert(
      WorkoutLogsCompanion(
        workoutId: Value(workoutId),
        planId: Value(planId),
        executedAt: Value(DateTime.now()),
        totalVolume: Value(calculatedVolume.toDouble()),
        durationMinutes: const Value(0),
        executionFeedback: Value(feedbackJson),
      ),
    );
  }

  Future<List<WorkoutLog>> getWeeklyVolumeStats() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 6));
    return await (select(
      workoutLogs,
    )..where((t) => t.executedAt.isBiggerOrEqualValue(sevenDaysAgo))).get();
  }

  // --- NEW: PLAN QUERIES ---
  // 1. Fetch the umbrella plan details
  Future<WorkoutPlan> getPlan(int planId) {
    return (select(
      workoutPlans,
    )..where((t) => t.id.equals(planId))).getSingle();
  }

  // 2. Fetch the full calendar schedule (Left Join because Rest Days have a null workoutId!)
  Future<List<TypedResult>> getPlanSchedule(int planId) {
    return (select(workoutPlanDays).join([
            leftOuterJoin(
              workouts,
              workouts.id.equalsExp(workoutPlanDays.workoutId),
            ),
          ])
          ..where(workoutPlanDays.planId.equals(planId))
          ..orderBy([OrderingTerm.asc(workoutPlanDays.dayNumber)]))
        .get();
  }

  Future<void> wipeAllUserData() async {
    // Delete tables in reverse order of dependencies
    await delete(workoutPlanDays).go();
    await delete(workoutPlans).go();
    await delete(exerciseLogs).go();
    await delete(workoutLogs).go();
    await delete(workoutExercises).go();
    await delete(workouts).go();
  }

  // --- MANUAL PLAN BUILDER LOGIC ---
  Future<int> createManualPlan(
    String title,
    int weeks,
    Map<int, int> scheduleWorkoutIds,
  ) async {
    return transaction(() async {
      // 1. Create the Umbrella Plan
      final planId = await into(workoutPlans).insert(
        WorkoutPlansCompanion.insert(
          title: title,
          totalWeeks: Value(weeks),
          goal: const Value('Custom Plan'),
        ),
      );

      // 2. Loop through every day and link the workouts
      final totalDays = weeks * 7;
      for (int i = 1; i <= totalDays; i++) {
        final workoutId =
            scheduleWorkoutIds[i]; // Will be null if it's a rest day
        await into(workoutPlanDays).insert(
          WorkoutPlanDaysCompanion.insert(
            planId: planId,
            dayNumber: i,
            workoutId: Value(workoutId),
          ),
        );
      }
      return planId; // Return ID so UI can navigate to it
    });
  }

  // --- EDIT PLAN LOGIC ---
  Future<void> updateManualPlan(
    int planId,
    String title,
    int weeks,
    Map<int, int> scheduleWorkoutIds,
  ) async {
    return transaction(() async {
      // 1. Update the Umbrella Plan details
      await (update(workoutPlans)..where((t) => t.id.equals(planId))).write(
        WorkoutPlansCompanion(title: Value(title), totalWeeks: Value(weeks)),
      );

      // 2. Wipe the old schedule completely
      await (delete(
        workoutPlanDays,
      )..where((t) => t.planId.equals(planId))).go();

      // 3. Insert the newly mapped schedule
      final totalDays = weeks * 7;
      for (int i = 1; i <= totalDays; i++) {
        final workoutId = scheduleWorkoutIds[i];
        await into(workoutPlanDays).insert(
          WorkoutPlanDaysCompanion.insert(
            planId: planId,
            dayNumber: i,
            workoutId: Value(workoutId),
          ),
        );
      }
    });
  }

  Future<void> startPlan(int planId) {
    return (update(workoutPlans)..where((t) => t.id.equals(planId))).write(
      WorkoutPlansCompanion(startDate: Value(DateTime.now())),
    );
  }

  Future<void> resetPlanProgress(int planId) async {
    await transaction(() async {
      await (update(workoutPlans)..where((t) => t.id.equals(planId))).write(
        const WorkoutPlansCompanion(
          startDate: Value(null),
          completedAt: Value(null),
        ),
      );
      await (update(workoutPlanDays)..where((t) => t.planId.equals(planId)))
          .write(const WorkoutPlanDaysCompanion(isCompleted: Value(false)));
    });
  }

  Future<void> completePlan(int planId) {
    return (update(workoutPlans)..where((t) => t.id.equals(planId))).write(
      WorkoutPlansCompanion(completedAt: Value(DateTime.now())),
    );
  }

  // --- FIX 1: DEEP SEARCH WORKOUTS BY EXERCISE TITLE ---

  // --- NEW: Stream for the Dashboard ---
  Stream<List<PlanLogData>> watchRecentPlanLogs() {
    final query =
        select(planLogs).join([
            innerJoin(workoutPlans, workoutPlans.id.equalsExp(planLogs.planId)),
          ])
          ..orderBy([OrderingTerm.desc(planLogs.completedAt)])
          ..limit(5); // Show last 5 completed plans

    return query.watch().map((rows) {
      return rows.map((row) {
        return PlanLogData(
          row.readTable(planLogs),
          row.readTable(workoutPlans),
        );
      }).toList();
    });
  }

  Stream<List<Workout>> watchFilteredWorkouts(String query) {
    if (query.trim().isEmpty) {
      return (select(
        workouts,
      )..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();
    }

    final q = '%${query.trim()}%';
    final titleMatch = workouts.title.like(q);

    // Looks inside the workout to see if any exercise matches the query
    final exerciseMatch = existsQuery(
      select(workoutExercises).join([
        innerJoin(
          exercises,
          exercises.id.equalsExp(workoutExercises.exerciseId),
        ),
      ])..where(
        workoutExercises.workoutId.equalsExp(workouts.id) &
            exercises.name.like(q),
      ),
    );

    return (select(workouts)
          ..where((t) => titleMatch | exerciseMatch)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .watch();
  }

  // --- FIX 2: REAL-TIME DASHBOARD LOGS ---
  Stream<List<WorkoutLog>> watchWeeklyVolumeStats() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 6));
    return (select(
      workoutLogs,
    )..where((t) => t.executedAt.isBiggerOrEqualValue(sevenDaysAgo))).watch();
  }

  Stream<List<TypedResult>> watchRecentWorkoutLogsWithTitles({int limit = 10}) {
    return (select(workoutLogs).join([
            innerJoin(workouts, workouts.id.equalsExp(workoutLogs.workoutId)),
          ])
          ..orderBy([OrderingTerm.desc(workoutLogs.executedAt)])
          ..limit(limit))
        .watch();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_minds.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
