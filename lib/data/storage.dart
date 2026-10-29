import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the app keeps its single JSON file.
abstract class StateStorage {
  Future<String?> read();
  Future<void> write(String json);
  Future<void> clear();

  /// Keeps the current file under another name when it can't be read,
  /// so starting fresh never destroys it.
  Future<void> keepUnreadableCopy();
}

/// Stores the data in the app's private folder on the phone.
/// Writes go to a temporary file first, so a crash never leaves half a file.
class FileStateStorage implements StateStorage {
  FileStateStorage({this.fileName = 'open_maternity.json'});

  final String fileName;
  Future<File>? _file;

  Future<File> _target() {
    return _file ??= getApplicationSupportDirectory().then((Directory dir) async {
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return File('${dir.path}${Platform.pathSeparator}$fileName');
    });
  }

  @override
  Future<String?> read() async {
    final File f = await _target();
    if (!f.existsSync()) {
      return null;
    }
    return f.readAsString();
  }

  @override
  Future<void> write(String json) async {
    final File f = await _target();
    final File tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> clear() async {
    final File f = await _target();
    if (f.existsSync()) {
      await f.delete();
    }
  }

  @override
  Future<void> keepUnreadableCopy() async {
    final File f = await _target();
    if (f.existsSync()) {
      await f.copy('${f.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}');
    }
  }
}

/// Keeps the data in memory only. Used by tests.
class MemoryStateStorage implements StateStorage {
  MemoryStateStorage([this.value]);

  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    value = json;
    writes++;
  }

  @override
  Future<void> clear() async {
    value = null;
  }

  int unreadableCopies = 0;

  @override
  Future<void> keepUnreadableCopy() async {
    unreadableCopies++;
  }
}
