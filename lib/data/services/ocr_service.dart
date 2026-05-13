import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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

  Future<OcrResult?> recognizeText(File imageFile) async {
    try {
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
      
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

  Future<String?> recognizeTextInRegion(File imageFile, Rect region) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        debugPrint('OCR recognizeTextInRegion: Failed to decode image');
        return null;
      }

      final left = region.left.toInt().clamp(0, originalImage.width);
      final top = region.top.toInt().clamp(0, originalImage.height);
      final right = region.right.toInt().clamp(0, originalImage.width);
      final bottom = region.bottom.toInt().clamp(0, originalImage.height);
      
      final width = right - left;
      final height = bottom - top;
      
      if (width <= 0 || height <= 0) {
        debugPrint('OCR recognizeTextInRegion: Invalid region size');
        return null;
      }

      final croppedImage = img.copyCrop(originalImage, x: left, y: top, width: width, height: height);
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ocr_region_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(img.encodePng(croppedImage));
      
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(tempFile);
      final recognizedText = await _recognizer!.processImage(inputImage);
      
      await tempFile.delete();
      
      final text = recognizedText.text.trim();
      if (text.isEmpty) {
        debugPrint('OCR recognizeTextInRegion: No text found in region');
        return null;
      }
      
      return text;
    } catch (e) {
      debugPrint('OCR recognizeTextInRegion failed: $e');
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