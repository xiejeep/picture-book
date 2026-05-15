import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastUtil {
  static void show(
    String message, {
    Color? backgroundColor,
    Color textColor = Colors.white,
    ToastGravity gravity = ToastGravity.BOTTOM,
    int duration = 4,
    double fontSize = 18.0,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: gravity,
      timeInSecForIosWeb: duration,
      backgroundColor: backgroundColor ?? Colors.black87,
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  static void success(String message) {
    show(message, backgroundColor: Colors.green.shade600);
  }

  static void error(String message) {
    show(message, backgroundColor: const Color(0xFFDC2626));
  }

  static void warning(String message) {
    show(message, backgroundColor: Colors.orange.shade600);
  }

  static void info(String message) {
    show(message, backgroundColor: Colors.blue.shade600);
  }
}
