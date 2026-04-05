import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// FIX 2: Ensure Drift and the Database are imported!
import 'package:drift/drift.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DriveSyncService {
  final AppDatabase _db;
  DriveSyncService(this._db);
  // 1. Paste your newly created WEB Client ID right here!
  static final String _webClientId =
      dotenv.env['WEB_CLIENT_ID'] ?? 'Missing Web Client ID';

  // 2. V7 uses the Singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  final String _backupDbName = 'workout_minds_backup.sqlite';
  final String _backupProfileName = 'workout_minds_profile.json';

  // --- CORE AUTHENTICATION ---
  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      // Initialize with the Web Client ID bridge
      await _googleSignIn.initialize(serverClientId: _webClientId);

      GoogleSignInAccount? account;

      // Try lightweight auth first (replaces signInSilently)
      try {
        final result = _googleSignIn.attemptLightweightAuthentication();
        account = result is Future ? await result : result;
      } catch (e) {
        debugPrint("Silent Sign In Notice: $e");
      }

      // If that fails, show the bottom sheet (replaces signIn)
      if (account == null) {
        try {
          account = await _googleSignIn.authenticate();
        } catch (e) {
          debugPrint("====== GOOGLE SIGN IN CRASH ======");
          debugPrint(e.toString());
          return null;
        }
      }

      // Request Drive scopes
      final scopes = [drive.DriveApi.driveAppdataScope];

      var authorization = await account.authorizationClient
          .authorizationForScopes(scopes);

      if (authorization == null) {
        try {
          authorization = await account.authorizationClient.authorizeScopes(
            scopes,
          );
        } catch (e) {
          debugPrint("====== SCOPE AUTH CRASH ======");
          debugPrint(e.toString());
          return null;
        }
      }

      // V3 extension method: get the authClient using the scopes
      final authClient = authorization.authClient(scopes: scopes);

      return drive.DriveApi(authClient);
    } catch (e) {
      debugPrint("====== CRITICAL AUTH ERROR ======");
      debugPrint(e.toString());
      return null;
    }
  }

  // --- API HELPERS ---
  Future<String?> _getExistingBackupFileId(
    drive.DriveApi driveApi,
    String fileName,
  ) async {
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName'",
    );
    final files = fileList.files;
    if (files != null && files.isNotEmpty) {
      return files.first.id;
    }
    return null;
  }

  // --- NEW HELPER: Upload any file ---
  Future<void> _uploadFile(
    drive.DriveApi driveApi,
    File localFile,
    String cloudName,
  ) async {
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$cloudName'",
    );
    final existingId = fileList.files?.firstOrNull?.id;
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());

    if (existingId != null) {
      // FIX: Do NOT send the parents field on an update request!
      final fileToUpdate = drive.File()..name = cloudName;
      await driveApi.files.update(fileToUpdate, existingId, uploadMedia: media);
    } else {
      // CREATE: Must specify the hidden appDataFolder!
      final fileToCreate = drive.File()
        ..name = cloudName
        ..parents = ['appDataFolder'];
      await driveApi.files.create(fileToCreate, uploadMedia: media);
    }
  }

  Future<bool> _downloadFile(
    drive.DriveApi driveApi,
    String cloudName,
    File targetFile,
  ) async {
    final existingId = await _getExistingBackupFileId(driveApi, cloudName);
    if (existingId == null) return false;

    final response =
        await driveApi.files.get(
              existingId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final sink = targetFile.openWrite();
    await response.stream.pipe(sink);
    await sink.close();
    return true;
  }

  // --- PUBLIC METHODS ---

  /// CHECKS if a backup exists in the cloud without downloading it
  Future<bool> hasBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final existingFileId = await _getExistingBackupFileId(
        driveApi,
        _backupDbName,
      );
      return existingFileId != null;
    } catch (e) {
      debugPrint("Check Backup Error: $e");
      return false;
    }
  }

  Future<bool> backupToCloud(
    String profileJson, {
    Function(String)? onStatus,
  }) async {
    try {
      onStatus?.call('Authenticating with Google...');
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        onStatus?.call('Authentication canceled.');
        return false;
      }

      final dbFolder = await getApplicationDocumentsDirectory();
      final localDbFile = File(p.join(dbFolder.path, 'workout_minds.sqlite'));

      // --- SMART MERGE LOGIC ---
      onStatus?.call('Checking for existing cloud backups...');
      final cloudDbId = await _getExistingBackupFileId(driveApi, _backupDbName);

      if (cloudDbId != null) {
        onStatus?.call('Cloud backup found. Preparing merge...');

        // 1. Export local workouts to memory
        final localWorkouts = await _db.select(_db.workouts).get();
        List<Map<String, dynamic>> localPayloads = [];

        for (var w in localWorkouts) {
          final mappings = await (_db.select(
            _db.workoutExercises,
          )..where((t) => t.workoutId.equals(w.id))).get();
          List<Map<String, dynamic>> exList = [];
          for (var map in mappings) {
            final ex = await (_db.select(
              _db.exercises,
            )..where((t) => t.id.equals(map.exerciseId))).getSingle();
            exList.add({
              'name': ex.name,
              'muscleGroup': ex.muscleGroup,
              'imageUrl': ex.imageUrl,
              'localImagePath': ex.localImagePath,
              'targetSets': map.targetSets,
              'targetReps': map.targetReps,
              'targetDurationSeconds': map.targetDurationSeconds,
              'restSecondsAfterSet': map.restSecondsAfterSet,
              'restSecondsAfterExercise': map.restSecondsAfterExercise,
              'orderIndex': map.orderIndex,
            });
          }
          localPayloads.add({
            'workout': {'title': w.title, 'difficultyLevel': w.difficultyLevel},
            'exercises': exList,
          });
        }

        // --- FIX 3: Export local Plans to memory ---
        final localPlans = await _db.select(_db.workoutPlans).get();
        List<Map<String, dynamic>> localPlanPayloads = [];

        for (var plan in localPlans) {
          final days = await (_db.select(
            _db.workoutPlanDays,
          )..where((t) => t.planId.equals(plan.id))).get();
          List<Map<String, dynamic>> dayList = [];

          for (var day in days) {
            String? workoutTitle;
            if (day.workoutId != null) {
              // We must save the TITLE, not the ID, because IDs will change when merged with the cloud!
              final w = await (_db.select(
                _db.workouts,
              )..where((t) => t.id.equals(day.workoutId!))).getSingleOrNull();
              workoutTitle = w?.title;
            }
            dayList.add({
              'dayNumber': day.dayNumber,
              'workoutTitle': workoutTitle,
              'notes': day.notes,
            });
          }
          localPlanPayloads.add({
            'title': plan.title,
            'description': plan.description,
            'goal': plan.goal,
            'totalWeeks': plan.totalWeeks,
            'days': dayList,
          });
        }

        // 2. Download Cloud DB (temporarily overwrites local file with cloud history)
        onStatus?.call('Downloading cloud history...');
        await _downloadFile(driveApi, _backupDbName, localDbFile);

        // 3. Re-inject the new local workouts into the downloaded cloud DB
        onStatus?.call('Merging new local workouts...');
        await _db.transaction(() async {
          for (var payload in localPayloads) {
            final title = payload['workout']['title'];

            // Check if this workout already exists in the cloud DB
            final exists = await (_db.select(
              _db.workouts,
            )..where((t) => t.title.equals(title))).getSingleOrNull();

            if (exists == null) {
              // Insert the missing local workout into the DB
              final newWorkoutId = await _db
                  .into(_db.workouts)
                  .insert(
                    WorkoutsCompanion.insert(
                      title: title,
                      difficultyLevel:
                          payload['workout']['difficultyLevel'] ?? 'Custom',
                      aiGenerated: const Value(false),
                    ),
                  );

              for (var exData in payload['exercises']) {
                int exId;
                final existingEx =
                    await (_db.select(_db.exercises)
                          ..where((t) => t.name.equals(exData['name']))
                          ..limit(1))
                        .getSingleOrNull();

                if (existingEx != null) {
                  exId = existingEx.id;
                } else {
                  exId = await _db
                      .into(_db.exercises)
                      .insert(
                        ExercisesCompanion.insert(
                          name: exData['name'],
                          muscleGroup: exData['muscleGroup'] ?? 'Custom',
                          imageUrl: Value(exData['imageUrl']),
                          localImagePath: Value(exData['localImagePath']),
                          isCustom: const Value(true),
                        ),
                      );
                }

                await _db
                    .into(_db.workoutExercises)
                    .insert(
                      WorkoutExercisesCompanion.insert(
                        workoutId: newWorkoutId,
                        exerciseId: exId,
                        orderIndex: exData['orderIndex'],
                        targetSets: exData['targetSets'],
                        targetReps: Value(exData['targetReps']),
                        targetDurationSeconds: Value(
                          exData['targetDurationSeconds'],
                        ),
                        restSecondsAfterSet:
                            exData['restSecondsAfterSet'] ?? 60,
                        restSecondsAfterExercise:
                            exData['restSecondsAfterExercise'] ?? 90,
                      ),
                    );
              }
            }
          }
          // Now inject the plans
          for (var pData in localPlanPayloads) {
            final planTitle = pData['title'];
            final exists = await (_db.select(
              _db.workoutPlans,
            )..where((t) => t.title.equals(planTitle))).getSingleOrNull();

            if (exists == null) {
              final newPlanId = await _db
                  .into(_db.workoutPlans)
                  .insert(
                    WorkoutPlansCompanion.insert(
                      title: planTitle,
                      description: Value(pData['description']),
                      goal: Value(pData['goal']),
                      totalWeeks: Value(pData['totalWeeks']),
                    ),
                  );

              for (var day in pData['days']) {
                int? mappedWorkoutId;
                if (day['workoutTitle'] != null) {
                  // Find the new Cloud ID for the workout using the Title
                  final w =
                      await (_db.select(_db.workouts)
                            ..where((t) => t.title.equals(day['workoutTitle'])))
                          .getSingleOrNull();
                  mappedWorkoutId = w?.id;
                }

                await _db
                    .into(_db.workoutPlanDays)
                    .insert(
                      WorkoutPlanDaysCompanion.insert(
                        planId: newPlanId,
                        dayNumber: day['dayNumber'],
                        workoutId: Value(mappedWorkoutId),
                        notes: Value(day['notes']),
                      ),
                    );
              }
            }
          }
        });
      }

      // --- UPLOAD FINAL MERGED DB ---
      if (await localDbFile.exists()) {
        onStatus?.call('Uploading unified Database...');
        await _uploadFile(driveApi, localDbFile, _backupDbName);
      }

      // 4. Upload Profile JSON
      onStatus?.call('Uploading Profile Data...');
      final tempDir = await getTemporaryDirectory();
      final localProfileFile = File(p.join(tempDir.path, 'temp_profile.json'));
      await localProfileFile.writeAsString(profileJson);
      await _uploadFile(driveApi, localProfileFile, _backupProfileName);

      onStatus?.call('Backup Complete!');
      return true;
    } catch (e) {
      debugPrint("Backup Error: $e");
      onStatus?.call('Error: Google API rejected the request.');
      if (e.toString().contains('invalid_token') ||
          e.toString().contains('Access was denied')) {
        _googleSignIn.signOut().ignore();
      }
      return false;
    }
  }

  /// RESTORE: Pulls SQLite DB and returns the JSON string
  Future<String?> restoreFromCloud({Function(String)? onStatus}) async {
    try {
      onStatus?.call('Authenticating with Google...');
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        onStatus?.call('Authentication canceled.');
        return null;
      }

      final dbFolder = await getApplicationDocumentsDirectory();

      // 1. Download Database
      onStatus?.call('Downloading Database...');
      final localDbFile = File(p.join(dbFolder.path, 'workout_minds.sqlite'));
      final dbExists = await _downloadFile(
        driveApi,
        _backupDbName,
        localDbFile,
      );

      if (!dbExists) {
        onStatus?.call('No database backup found.');
      }

      // 2. Download Profile JSON
      onStatus?.call('Downloading Profile Data...');
      final tempDir = await getTemporaryDirectory();
      final localProfileFile = File(p.join(tempDir.path, 'temp_profile.json'));
      final jsonExists = await _downloadFile(
        driveApi,
        _backupProfileName,
        localProfileFile,
      );

      if (jsonExists) {
        onStatus?.call('Finalizing restore...');
        return await localProfileFile.readAsString();
      }

      onStatus?.call('No profile backup found.');
      return null;
    } catch (e) {
      debugPrint("Restore Error: $e");
      onStatus?.call('Error: Failed to fetch from Google.');
      if (e.toString().contains('invalid_token') ||
          e.toString().contains('Access was denied')) {
        _googleSignIn.signOut().ignore();
      }
      return null;
    }
  }

  /// WIPE: Deletes all app data from the user's hidden Google Drive AppData folder
  Future<bool> deleteCloudBackup({Function(String)? onStatus}) async {
    try {
      onStatus?.call('Authenticating with Google...');
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      onStatus?.call('Locating cloud backups...');
      final dbId = await _getExistingBackupFileId(driveApi, _backupDbName);
      final profileId = await _getExistingBackupFileId(
        driveApi,
        _backupProfileName,
      );

      bool deletedAnything = false;

      if (dbId != null) {
        onStatus?.call('Deleting Database Backup...');
        await driveApi.files.delete(dbId);
        deletedAnything = true;
      }

      if (profileId != null) {
        onStatus?.call('Deleting Profile Backup...');
        await driveApi.files.delete(profileId);
        deletedAnything = true;
      }

      onStatus?.call(
        deletedAnything
            ? 'Cloud backups permanently deleted.'
            : 'No backups found to delete.',
      );
      return true;
    } catch (e) {
      debugPrint("Wipe Backup Error: $e");
      onStatus?.call('Error: Failed to delete cloud backups.');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
