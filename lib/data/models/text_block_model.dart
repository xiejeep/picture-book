import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'text_block_model.g.dart';

@HiveType(typeId: 2)
class TextBlockModel extends HiveObject {
  @HiveField(0)
  final double left;

  @HiveField(1)
  final double top;

  @HiveField(2)
  final double right;

  @HiveField(3)
  final double bottom;

  @HiveField(4)
  final String text;

  @HiveField(5)
  final bool isDeleted;

  @HiveField(6)
  final String? translatedText;

  @HiveField(7)
  final String? aiTranslatedText;

  TextBlockModel({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.text,
    this.isDeleted = false,
    this.translatedText,
    this.aiTranslatedText,
  });

  Rect get boundingBox => Rect.fromLTRB(left, top, right, bottom);

  static TextBlockModel fromData({
    required Rect boundingBox,
    required String text,
    bool isDeleted = false,
    String? translatedText,
    String? aiTranslatedText,
  }) {
    return TextBlockModel(
      left: boundingBox.left,
      top: boundingBox.top,
      right: boundingBox.right,
      bottom: boundingBox.bottom,
      text: text,
      isDeleted: isDeleted,
      translatedText: translatedText,
      aiTranslatedText: aiTranslatedText,
    );
  }

  TextBlockModel copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
    String? text,
    bool? isDeleted,
    String? translatedText,
    String? aiTranslatedText,
    bool clearTranslatedText = false,
    bool clearAiTranslatedText = false,
  }) {
    return TextBlockModel(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      text: text ?? this.text,
      isDeleted: isDeleted ?? this.isDeleted,
      translatedText: clearTranslatedText ? null : (translatedText ?? this.translatedText),
      aiTranslatedText: clearAiTranslatedText ? null : (aiTranslatedText ?? this.aiTranslatedText),
    );
  }
}