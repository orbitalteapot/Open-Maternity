import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../data/calc.dart';
import '../data/models.dart';

const String backupAppId = 'open-maternity';
const int backupFormat = 1;

class BackupFile {
  const BackupFile({required this.data, this.exportedAt});
  final AppData data;
  final DateTime? exportedAt;
}

/// The backup is the app's own data, as readable JSON, with a small header.
String encodeBackup(AppData data, DateTime now) {
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'app': backupAppId,
    'format': backupFormat,
    'exported': now.toUtc().toIso8601String(),
    'data': data.toJson(),
  });
}

/// Returns null when the text is not an Open Maternity backup.
BackupFile? decodeBackup(String text) {
  try {
    final Object? json = jsonDecode(text);
    if (json is! Map) {
      return null;
    }
    if (json['app'] != backupAppId || json['data'] is! Map) {
      return null;
    }
    final Object? format = json['format'];
    if (format is! int || format > backupFormat) {
      return null;
    }
    final Object? exported = json['exported'];
    return BackupFile(
      data: AppData.fromJson(json['data']),
      exportedAt: exported is String ? DateTime.tryParse(exported)?.toLocal() : null,
    );
  } catch (_) {
    return null;
  }
}

String backupFileName(DateTime now) => 'open-maternity-backup-${isoDate(now)}.json';

/// Lets the user choose where to save the backup. Returns false if cancelled.
Future<bool> saveBackup(AppData data, DateTime now) async {
  final Uint8List bytes = Uint8List.fromList(utf8.encode(encodeBackup(data, now)));
  final Uri? saved = await FilePicker.saveFile(
    fileName: backupFileName(now),
    bytes: bytes,
    mimeType: 'application/json',
  );
  return saved != null;
}

/// Lets the user pick a backup file. Returns its text, or null if cancelled.
Future<String?> pickBackupText() async {
  final PlatformFile? file = await FilePicker.pickFile();
  if (file == null) {
    return null;
  }
  final Uint8List bytes = await file.readAsBytes();
  return utf8.decode(bytes, allowMalformed: true);
}
