class TextUtils {
  static bool isEnglishText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    for (final char in trimmed.split('')) {
      final codeUnit = char.codeUnitAt(0);
      if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) {
        return false;
      }
    }
    return true;
  }
}
