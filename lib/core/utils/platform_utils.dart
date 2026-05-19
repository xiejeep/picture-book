import 'dart:io';

abstract class PlatformUtils {
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isMobile => Platform.isIOS || Platform.isAndroid;

  static bool get supportsMlKit => isMobile;

  static bool get supportsSystemTts => isMobile;

  static bool get supportsSupertonic => isMobile;
}
