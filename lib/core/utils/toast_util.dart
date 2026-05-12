import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastUtil {
  static void show(
    String message, {
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
    ToastGravity gravity = ToastGravity.BOTTOM,
    int duration = 2,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      timeInSecForIosWeb: duration,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: 16.0,
    );
  }

  static void success(String message) {
    show(message, backgroundColor: Colors.green);
  }

  static void error(String message) {
    show(message, backgroundColor: Colors.red);
  }

  static void warning(String message) {
    show(message, backgroundColor: Colors.orange);
  }

  static void info(String message) {
    show(message, backgroundColor: Colors.blue);
  }
}