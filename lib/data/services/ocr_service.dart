import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract class OcrResult {
  String get text;
  List<OcrBlock> get blocks;
}

abstract class OcrBlock {
  String get text;
  Rect get boundingBox;
  List<Point<int>> get cornerPoints;
  List<String> get recognizedLanguages;
}

class OcrService {
  static final OcrService instance = OcrService._();
  TextRecognizer? _recognizer;
  OcrService._();

  Future<bool> isAvailable() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    return true;
  }

  Future<OcrResult?> recognizeText(File imageFile, {String script = 'latin'}) async {
    try {
      _recognizer ??= TextRecognizer(script: script == 'chinese' ? TextRecognitionScript.chinese : TextRecognitionScript.latin);
      
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _recognizer!.processImage(inputImage);
      
      final blocks = <OcrBlock>[];
      for (final block in recognizedText.blocks) {
        blocks.add(_OcrBlockImpl(
          text: block.text,
          boundingBox: block.boundingBox,
          cornerPoints: block.cornerPoints.map((p) => Point<int>(p.x.toInt(), p.y.toInt())).toList(),
          recognizedLanguages: block.recognizedLanguages.toList(),
        ));
      }
      
      return _OcrResultImpl(
        text: recognizedText.text,
        blocks: blocks,
      );
    } catch (e) {
      debugPrint('OCR recognizeText failed: $e');
      return null;
    }
  }

  Future<void> close() async {
    _recognizer?.close();
    _recognizer = null;
  }
}

class _OcrResultImpl implements OcrResult {
  final String text;
  final List<OcrBlock> blocks;

  _OcrResultImpl({required this.text, required this.blocks});
}

class _OcrBlockImpl implements OcrBlock {
  final String text;
  final Rect boundingBox;
  final List<Point<int>> cornerPoints;
  final List<String> recognizedLanguages;

  _OcrBlockImpl({
    required this.text,
    required this.boundingBox,
    required this.cornerPoints,
    required this.recognizedLanguages,
  });
}