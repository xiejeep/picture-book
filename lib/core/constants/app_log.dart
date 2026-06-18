import 'package:flutter/foundation.dart';

class AppLog {
  /// When true, debugPrint calls that expose book text content
  /// (OCR/AI output, translated text, text block content, etc.)
  /// are enabled. Default is false to protect child reading privacy.
  static const bool verboseContentLog = false;

  /// Calls [debugPrint] only when [verboseContentLog] is true.
  /// Use this for any log message that contains user/child book content.
  static void content(Object? message) {
    if (verboseContentLog) {
      debugPrint(message?.toString());
    }
  }
}
