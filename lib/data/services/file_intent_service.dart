import 'package:flutter/services.dart';

class FileIntentService {
  static String? _pendingPath;
  static void Function(String)? _onFile;

  static void initialize() {
    const channel = MethodChannel('com.example.picture_book_app/file_intent');

    channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileIntent') {
        final path = call.arguments as String?;
        if (path != null) {
          _onFile?.call(path);
        }
      }
    });

    channel.invokeMethod<String?>('getPendingFileIntent').then((path) {
      if (path != null) {
        if (_onFile != null) {
          _onFile!(path);
        } else {
          _pendingPath = path;
        }
      }
    });
  }

  static void register(void Function(String path) onFile) {
    _onFile = onFile;
    final p = _pendingPath;
    if (p != null) {
      _pendingPath = null;
      onFile(p);
    }
  }

  static void unregister() {
    _onFile = null;
  }
}
