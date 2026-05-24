import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'package:workout_minds/data/local/database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workout_minds/repositories/providers.dart';

class _AuthenticatedClient extends http.BaseClient {
  _AuthenticatedClient(this._credentials, this._inner);

  final GoogleSignInClientAuthorization _credentials;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer ${_credentials.accessToken}';
    return _inner.send(request);
  }
}

class DriveSyncService {
  final Ref _ref; // FIX: Hold the Ref, not the DB, to survive DB rebuilds
  AppDatabase get _db => _ref.read(databaseProvider);

  static final String _webClientId = dotenv.env['WEB_CLIENT_ID'] ?? '';
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInAccount? _currentUser;
  bool _initialized = false;
  drive.DriveApi?
  _cachedDriveApi; // FIX: Prevent overlapping authorization prompts!

  static const List<String> _driveScopes = [drive.DriveApi.driveAppdataScope];
  final String _backupDbName = 'workout_minds_backup.sqlite';
  final String _backupProfileName = 'workout_minds_profile.json';

  DriveSyncService(this._ref);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _googleSignIn.initialize(
        serverClientId: _webClientId.isNotEmpty ? _webClientId : null,
      );

      _googleSignIn.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _currentUser = event.user;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _currentUser = null;
          _cachedDriveApi = null; // Clear cache on sign out
        }
      }, onError: (e) => debugPrint('Auth event error: $e'));

      _googleSignIn.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint('Init / silent sign-in failed: $e');
    }
  }

  bool get isSignedIn => _currentUser != null;
  String? get currentUserEmail => _currentUser?.email;

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      await init();
      if (_cachedDriveApi != null) {
        return _cachedDriveApi; // FIX: Use cached API
      }

      if (_currentUser == null) {
        if (_googleSignIn.supportsAuthenticate()) {
          await _googleSignIn.authenticate();
        } else {
          return null;
        }
      }

      final user = _currentUser;
      if (user == null) return null;

      final authorization = await user.authorizationClient.authorizeScopes(
        _driveScopes,
      );
      final authClient = _AuthenticatedClient(authorization, http.Client());

      _cachedDriveApi = drive.DriveApi(authClient); // Cache for session
      return _cachedDriveApi;
    } catch (e) {
      debugPrint('Critical auth error: $e');
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
      final fileToUpdate = drive.File()..name = cloudName;
      await driveApi.files.update(fileToUpdate, existingId, uploadMedia: media);
    } else {
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
      debugPrint('Check Backup Error: $e');
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

      onStatus?.call('Checking for existing cloud backups...');
      final cloudDbId = await _getExistingBackupFileId(driveApi, _backupDbName);

      if (cloudDbId != null) {
        onStatus?.call('Cloud backup found. Preparing merge...');

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

        onStatus?.call('Downloading cloud history...');
        await _downloadFile(driveApi, _backupDbName, localDbFile);

        onStatus?.call('Merging new local workouts...');
        await _db.transaction(() async {
          for (var payload in localPayloads) {
            final title = payload['workout']['title'];
            final exists = await (_db.select(
              _db.workouts,
            )..where((t) => t.title.equals(title))).getSingleOrNull();

            if (exists == null) {
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

      if (await localDbFile.exists()) {
        onStatus?.call('Uploading unified Database...');
        await _uploadFile(driveApi, localDbFile, _backupDbName);
      }

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
      return false;
    }
  }

  Future<String?> restoreFromCloud({Function(String)? onStatus}) async {
    try {
      onStatus?.call('Authenticating with Google...');
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        onStatus?.call('Authentication canceled.');
        return null;
      }

      final dbFolder = await getApplicationDocumentsDirectory();

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
      debugPrint('Restore Error: $e');
      onStatus?.call('Error: Failed to fetch from Google.');
      return null;
    }
  }

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
      debugPrint('Wipe Backup Error: $e');
      onStatus?.call('Error: Failed to delete cloud backups.');
      return false;
    }
  }

  Future<bool> signIn({Function(String)? onStatus}) async {
    try {
      onStatus?.call('Signing in with Google...');
      // By calling _getDriveApi directly here, we trigger the sequence: Identity -> Authorization.
      // Doing this sequentially in one function prevents the overlapping bottom sheets!
      final api = await _getDriveApi();
      return api != null;
    } catch (e) {
      debugPrint('Manual Sign-In Error: $e');
      onStatus?.call('Sign in failed.');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
