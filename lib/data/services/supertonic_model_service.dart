import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/constants.dart';

class SupertonicModelService {
  static final SupertonicModelService _instance = SupertonicModelService._internal();
  static SupertonicModelService get instance => _instance;
  SupertonicModelService._internal();

  Future<String> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${AppConstants.supertonicModelsDirName}/${AppConstants.supertonicOnnxDirName}';
  }

  Future<String> getModelsParentDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${AppConstants.supertonicModelsDirName}';
  }

  Future<bool> hasAllModels() async {
    final modelsDir = await getModelsDirectory();
    final dir = Directory(modelsDir);
    
    if (!dir.existsSync()) {
      return false;
    }

    for (final fileName in AppConstants.supertonicRequiredModelFiles) {
      final file = File('$modelsDir/$fileName');
      if (!file.existsSync()) {
        return false;
      }
    }

    return true;
  }

  List<String> getMissingFiles(String modelsDir) {
    final missing = <String>[];
    
    for (final fileName in AppConstants.supertonicRequiredModelFiles) {
      final file = File('$modelsDir/$fileName');
      if (!file.existsSync()) {
        missing.add(fileName);
      }
    }

    return missing;
  }

  Future<List<String>> checkMissingFiles() async {
    final modelsDir = await getModelsDirectory();
    return getMissingFiles(modelsDir);
  }

  Future<int> getModelsSize() async {
    final modelsDir = await getModelsDirectory();
    final dir = Directory(modelsDir);
    
    if (!dir.existsSync()) {
      return 0;
    }

    int totalSize = 0;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) {
        totalSize += entity.lengthSync();
      }
    }

    return totalSize;
  }

  String formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Future<void> deleteModels() async {
    final modelsParentDir = await getModelsParentDirectory();
    final dir = Directory(modelsParentDir);
    
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  bool isBundledFile(String fileName) {
    return AppConstants.supertonicBundledFiles.contains(fileName);
  }

  bool isDownloadableFile(String fileName) {
    return AppConstants.supertonicDownloadableFiles.contains(fileName);
  }

  Future<void> ensureBundledFiles() async {
    final modelsDir = await getModelsDirectory();
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    for (final fileName in AppConstants.supertonicBundledFiles) {
      final targetFile = File('$modelsDir/$fileName');
      if (!targetFile.existsSync()) {
        debugPrint('Copying bundled file: $fileName');
        final assetPath = 'assets/onnx/$fileName';
        final byteData = await rootBundle.load(assetPath);
        await targetFile.writeAsBytes(byteData.buffer.asUint8List());
        debugPrint('Copied $fileName (${targetFile.lengthSync()} bytes)');
      }
    }
  }

  Future<List<String>> getMissingDownloadableFiles() async {
    final modelsDir = await getModelsDirectory();
    final missing = <String>[];
    
    for (final fileName in AppConstants.supertonicDownloadableFiles) {
      final file = File('$modelsDir/$fileName');
      if (!file.existsSync()) {
        missing.add(fileName);
      }
    }
    
    return missing;
  }
}