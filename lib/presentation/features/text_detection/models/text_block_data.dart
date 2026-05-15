import 'package:flutter/material.dart';

class TextBlockData {
  final String id;
  final Rect boundingBox;
  final String text;
  final bool isDeleted;
  final String? originalText;
  final String? aiEnhancedText;
  final String? translatedText;
  final String? aiTranslatedText;

  TextBlockData({
    required this.id,
    required this.boundingBox,
    required this.text,
    this.isDeleted = false,
    this.originalText,
    this.aiEnhancedText,
    this.translatedText,
    this.aiTranslatedText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boundingBox': boundingBox,
      'text': text,
      'isDeleted': isDeleted,
      'originalText': originalText,
      'aiEnhancedText': aiEnhancedText,
      'translatedText': translatedText,
      'aiTranslatedText': aiTranslatedText,
    };
  }

  factory TextBlockData.fromMap(Map<String, dynamic> map) {
    return TextBlockData(
      id: map['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      boundingBox: map['boundingBox'] as Rect,
      text: map['text'] as String,
      isDeleted: map['isDeleted'] as bool? ?? false,
      originalText: map['originalText'] as String?,
      aiEnhancedText: map['aiEnhancedText'] as String?,
      translatedText: map['translatedText'] as String?,
      aiTranslatedText: map['aiTranslatedText'] as String?,
    );
  }

  TextBlockData copyWith({
    String? id,
    Rect? boundingBox,
    String? text,
    bool? isDeleted,
    String? originalText,
    String? aiEnhancedText,
    String? translatedText,
    String? aiTranslatedText,
    bool clearOriginalText = false,
    bool clearAiEnhancedText = false,
    bool clearTranslatedText = false,
    bool clearAiTranslatedText = false,
  }) {
    return TextBlockData(
      id: id ?? this.id,
      boundingBox: boundingBox ?? this.boundingBox,
      text: text ?? this.text,
      isDeleted: isDeleted ?? this.isDeleted,
      originalText:
          clearOriginalText ? null : (originalText ?? this.originalText),
      aiEnhancedText:
          clearAiEnhancedText ? null : (aiEnhancedText ?? this.aiEnhancedText),
      translatedText:
          clearTranslatedText ? null : (translatedText ?? this.translatedText),
      aiTranslatedText: clearAiTranslatedText
          ? null
          : (aiTranslatedText ?? this.aiTranslatedText),
    );
  }
}
