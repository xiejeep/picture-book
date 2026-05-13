import 'package:flutter/material.dart';

class TextBlockData {
  final String id;
  Rect boundingBox;
  String text;
  bool isDeleted;
  String? originalText;
  String? aiEnhancedText;

  TextBlockData({
    required this.id,
    required this.boundingBox,
    required this.text,
    this.isDeleted = false,
    this.originalText,
    this.aiEnhancedText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boundingBox': boundingBox,
      'text': text,
      'isDeleted': isDeleted,
      'originalText': originalText,
      'aiEnhancedText': aiEnhancedText,
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
    );
  }

  TextBlockData copyWith({
    String? id,
    Rect? boundingBox,
    String? text,
    bool? isDeleted,
    String? originalText,
    String? aiEnhancedText,
  }) {
    return TextBlockData(
      id: id ?? this.id,
      boundingBox: boundingBox ?? this.boundingBox,
      text: text ?? this.text,
      isDeleted: isDeleted ?? this.isDeleted,
      originalText: originalText ?? this.originalText,
      aiEnhancedText: aiEnhancedText ?? this.aiEnhancedText,
    );
  }
}