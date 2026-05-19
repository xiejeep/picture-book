import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/constants.dart';
import 'supertonic_model_service.dart';

class DownloadProgress {
  final String fileName;
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final DownloadStatus status;
  final String? error;

  DownloadProgress({
    required this.fileName,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.error,
  });

  DownloadProgress copyWith({
    String? fileName,
    int? downloadedBytes,
    int? totalBytes,
    double? progress,
    DownloadStatus? status,
    String? error,
  }) {
    return DownloadProgress(
      fileName: fileName ?? this.fileName,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  String get progressText {
    if (totalBytes > 0) {
      final downloadedMB = downloadedBytes / (1024 * 1024);
      final totalMB = totalBytes / (1024 * 1024);
      return '${downloadedMB.toStringAsFixed(1)}MB / ${totalMB.toStringAsFixed(1)}MB';
    }
    return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

class SupertonicDownloadService {
  static final SupertonicDownloadService _instance = SupertonicDownloadService._internal();
  static SupertonicDownloadService get instance => _instance;
  SupertonicDownloadService._internal();

  final Map<String, http.Client> _clients = {};
  final Map<String, StreamController<DownloadProgress>> _progressControllers = {};
  bool _isDownloading = false;
  String? _currentFileName;
  List<String> _downloadQueue = [];

  bool get isDownloading => _isDownloading;
  String? get currentFileName => _currentFileName;
  List<String> get downloadQueue => _downloadQueue;

  Stream<DownloadProgress> getProgressStream(String fileName) {
    if (!_progressControllers.containsKey(fileName)) {
      _progressControllers[fileName] = StreamController<DownloadProgress>.broadcast();
    }
    return _progressControllers[fileName]!.stream;
  }

  void _updateProgress(String fileName, DownloadProgress progress) {
    if (_progressControllers.containsKey(fileName)) {
      _progressControllers[fileName]!.add(progress);
    }
  }

  Future<void> downloadAllModels({String source = 'modelscope'}) async {
    if (_isDownloading) {
      debugPrint('Already downloading');
      return;
    }

    _isDownloading = true;

    final modelsDir = await SupertonicModelService.instance.getModelsDirectory();
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    await SupertonicModelService.instance.ensureBundledFiles();

    for (final fileName in AppConstants.supertonicBundledFiles) {
      _updateProgress(fileName, DownloadProgress(
        fileName: fileName,
        status: DownloadStatus.completed,
        progress: 1.0,
      ));
    }

    _downloadQueue = List.from(AppConstants.supertonicDownloadableFiles);

    final urls = source == 'huggingface' 
        ? AppConstants.supertonicModelUrlsHuggingface 
        : AppConstants.supertonicModelUrlsModelscope;

    for (final fileName in _downloadQueue) {
      _currentFileName = fileName;
      final url = urls[fileName];

      if (url == null || url.isEmpty) {
        _updateProgress(fileName, DownloadProgress(
          fileName: fileName,
          status: DownloadStatus.failed,
          error: 'URL not found',
        ));
        continue;
      }

      try {
        await _downloadFile(fileName, url, modelsDir);
      } catch (e) {
        _updateProgress(fileName, DownloadProgress(
          fileName: fileName,
          status: DownloadStatus.failed,
          error: e.toString(),
        ));
      }
    }

    _isDownloading = false;
    _currentFileName = null;
    _downloadQueue = [];
  }

  Future<void> _downloadFile(String fileName, String url, String targetDir) async {
    final outputPath = '$targetDir/$fileName';
    final outputFile = File(outputPath);

    if (outputFile.existsSync()) {
      final fileSize = outputFile.lengthSync();
      debugPrint('$fileName already exists, skipping');
      _updateProgress(fileName, DownloadProgress(
        fileName: fileName,
        downloadedBytes: fileSize,
        totalBytes: fileSize,
        progress: 1.0,
        status: DownloadStatus.completed,
      ));
      return;
    }

    _updateProgress(fileName, DownloadProgress(
      fileName: fileName,
      status: DownloadStatus.downloading,
    ));

    final client = http.Client();
    _clients[fileName] = client;

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final sink = outputFile.openWrite();

      await response.stream.listen((data) {
        sink.add(data);
        downloadedBytes += data.length;
        
        final progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
        _updateProgress(fileName, DownloadProgress(
          fileName: fileName,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          progress: progress,
          status: DownloadStatus.downloading,
        ));
      }).asFuture();

      await sink.close();

      _updateProgress(fileName, DownloadProgress(
        fileName: fileName,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        status: DownloadStatus.completed,
      ));

      debugPrint('$fileName downloaded successfully');
    } catch (e) {
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }
      rethrow;
    } finally {
      client.close();
      _clients.remove(fileName);
    }
  }

  void cancelDownload() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();

    for (final controller in _progressControllers.values) {
      if (_currentFileName != null && controller.hasListener) {
        controller.add(DownloadProgress(
          fileName: _currentFileName!,
          status: DownloadStatus.cancelled,
        ));
      }
    }

    _isDownloading = false;
    _currentFileName = null;
    _downloadQueue = [];
  }

  void dispose() {
    cancelDownload();
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
  }
}