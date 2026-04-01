import 'dart:io';
import 'package:flutter/foundation.dart';
// This import powers the .authClient() extension method on line 53!
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DriveSyncService {
  // 1. Paste your newly created WEB Client ID right here!
  static const String _webClientId =
      '634732739534-u91a5bo2iujg8mcn5inhcpoahckmdegp.apps.googleusercontent.com';

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

  /// BACKUP: Pushes SQLite DB and Profile JSON to Google Drive
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

      onStatus?.call('Locating local files...');
      final dbFolder = await getApplicationDocumentsDirectory();

      // 1. Upload Database
      final localDbFile = File(p.join(dbFolder.path, 'workout_minds.sqlite'));
      if (await localDbFile.exists()) {
        onStatus?.call('Uploading Database...');
        await _uploadFile(driveApi, localDbFile, _backupDbName);
      }

      // 2. Upload Profile JSON
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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
