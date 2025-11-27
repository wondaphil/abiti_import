import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Handles uploading and restoring your local SQLite database
/// to Google Drive using the authenticated Google account.
class DriveBackup {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  );

  /// Uploads the local import_db.db file to Google Drive
  static Future<void> uploadBackup() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('User cancelled sign-in');

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final dbDir = await getDatabasesPath();
    final dbFile = File('$dbDir/import_db.db');

    if (!await dbFile.exists()) {
      throw Exception('Database file not found at $dbDir');
    }

    final media = drive.Media(dbFile.openRead(), await dbFile.length());
    final file = drive.File()
      ..name = 'inventory_backup.db'
      ..mimeType = 'application/x-sqlite3';

    // Try to find existing backup to replace
    final existing = await driveApi.files.list(
      q: "name='inventory_backup.db'",
      spaces: 'drive',
    );

    if (existing.files != null && existing.files!.isNotEmpty) {
      final fileId = existing.files!.first.id!;
      await driveApi.files.update(file, fileId, uploadMedia: media);
    } else {
      await driveApi.files.create(file, uploadMedia: media);
    }

    client.close();
  }

  /// Downloads the backup file from Google Drive and replaces local DB
  static Future<void> restoreBackup() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('User cancelled sign-in');

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final files = await driveApi.files.list(
      q: "name='inventory_backup.db'",
      spaces: 'drive',
    );

    if (files.files == null || files.files!.isEmpty) {
      throw Exception('No backup found on Google Drive');
    }

    final fileId = files.files!.first.id!;
    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final savePath = File('${await getDatabasesPath()}/import_db.db');
    final dataStream = media.stream;
    final sink = savePath.openWrite();
    await dataStream.pipe(sink);
    await sink.close();

    client.close();
  }
}

/// GoogleAuthClient wraps the auth headers for Drive API requests.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}