import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/supertonic_model_service.dart';
import '../../data/services/supertonic_download_service.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_util.dart';

class SupertonicModelPage extends StatefulWidget {
  const SupertonicModelPage({super.key});

  @override
  State<SupertonicModelPage> createState() => _SupertonicModelPageState();
}

class _SupertonicModelPageState extends State<SupertonicModelPage> {
  List<String> _missingFiles = [];
  List<String> _missingDownloadableFiles = [];
  bool _isChecking = false;
  bool _hasAllModels = false;
  int _modelsSize = 0;
  String _targetPath = '';

  bool _isDownloading = false;
  String? _currentDownloadFile;
  double _currentProgress = 0.0;
  String _currentProgressText = '';
  String _downloadSource = AppConstants.supertonicDefaultDownloadSource;
  final Map<String, DownloadProgress> _fileProgresses = {};
  final List<StreamSubscription<DownloadProgress>> _progressSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _checkModels();
    _listenDownloadProgress();
  }

  @override
  void dispose() {
    for (final subscription in _progressSubscriptions) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();
    super.dispose();
  }

  void _listenDownloadProgress() {
    for (final fileName in AppConstants.supertonicRequiredModelFiles) {
      final subscription = SupertonicDownloadService.instance.getProgressStream(fileName).listen((progress) {
        if (!mounted) return;
        setState(() {
          _fileProgresses[fileName] = progress;
          if (progress.fileName == SupertonicDownloadService.instance.currentFileName) {
            _currentProgress = progress.progress;
            _currentProgressText = progress.progressText;
            _currentDownloadFile = progress.fileName;
            _isDownloading = progress.status == DownloadStatus.downloading;
          }
        });

        if (progress.status == DownloadStatus.completed || progress.status == DownloadStatus.failed) {
          if (SupertonicDownloadService.instance.downloadQueue.isEmpty) {
            _onDownloadComplete();
          }
        }
      });
      _progressSubscriptions.add(subscription);
    }
  }

  void _onDownloadComplete() {
    setState(() {
      _isDownloading = false;
      _currentDownloadFile = null;
    });
    _checkModels();
  }

  Future<void> _checkModels() async {
    if (_isChecking) return;
    
    setState(() => _isChecking = true);
    ToastUtil.info('正在验证模型...');

    try {
      await SupertonicModelService.instance.ensureBundledFiles();
      _missingFiles = await SupertonicModelService.instance.checkMissingFiles();
      _missingDownloadableFiles = await SupertonicModelService.instance.getMissingDownloadableFiles();
      _hasAllModels = _missingFiles.isEmpty;
      _modelsSize = await SupertonicModelService.instance.getModelsSize();
      _targetPath = await SupertonicModelService.instance.getModelsDirectory();
      
      if (_hasAllModels) {
        ToastUtil.success('模型验证通过');
      } else {
        ToastUtil.warning('缺少 ${_missingFiles.length} 个模型文件');
      }
    } catch (e) {
      debugPrint('检查模型错误: $e');
      ToastUtil.error('验证失败: $e');
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _startDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _fileProgresses.clear();
    });

    try {
      await SupertonicDownloadService.instance.downloadAllModels(source: _downloadSource);
    } catch (e) {
      ToastUtil.error('下载失败: $e');
      setState(() => _isDownloading = false);
    }
  }

  void _cancelDownload() {
    SupertonicDownloadService.instance.cancelDownload();
    setState(() {
      _isDownloading = false;
      _currentDownloadFile = null;
      _currentProgress = 0.0;
    });
    ToastUtil.info('下载已取消');
  }

  Future<void> _deleteModels() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除所有 Supertonic 模型文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SupertonicModelService.instance.deleteModels();
      ToastUtil.success('模型已删除');
      await _checkModels();
    }
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: _targetPath));
    ToastUtil.success('路径已复制');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supertonic 模型管理'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradientOf(context),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBoxOf(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusSection(),
                const SizedBox(height: 24),
                if (!_hasAllModels) _buildDownloadSection(),
                if (_hasAllModels) _buildManageSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '模型状态',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.onSurfaceOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isChecking
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Icon(
                      _hasAllModels ? Icons.check_circle : Icons.error,
                      color: _hasAllModels ? Colors.green : AppTheme.errorOf(context),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasAllModels ? '模型已下载' : '模型未完全下载',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onSurfaceOf(context),
                            ),
                          ),
                          if (_hasAllModels)
                            Text(
                              '大小: ${SupertonicModelService.instance.formatSize(_modelsSize)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                              ),
                            ),
                          if (!_hasAllModels && _missingDownloadableFiles.isNotEmpty)
                            Text(
                              '需下载 ${_missingDownloadableFiles.length} 个文件 (约 377MB)',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.errorOf(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDownloadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '下载模型',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.onSurfaceOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isDownloading) _buildSourceSelector(),
              if (!_isDownloading) const SizedBox(height: 16),
              if (_isDownloading) _buildDownloadProgress(),
              if (!_isDownloading) _buildFileList(),
              const SizedBox(height: 16),
              if (_isDownloading)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cancelDownload,
                        icon: const Icon(Icons.cancel),
                        label: const Text('取消下载'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorOf(context).withValues(alpha: 0.85),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              if (!_isDownloading)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _missingDownloadableFiles.isEmpty ? null : _startDownload,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('开始下载'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOf(context).withValues(alpha: 0.85),
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isChecking ? null : _checkModels,
                        icon: const Icon(Icons.refresh),
                        label: const Text('验证'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryOf(context),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                '提示：下载需要稳定的网络连接，建议在 WiFi 环境下进行',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '下载源',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceOf(context),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _downloadSource,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: AppTheme.surfaceOf(context),
          ),
          items: AppConstants.supertonicDownloadSources.map((source) {
            return DropdownMenuItem(
              value: source['name'],
              child: Row(
                children: [
                  Text(source['label']!),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: source['region'] == '国内'
                          ? Colors.green.withValues(alpha: 0.1)
                          : AppTheme.primaryOf(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      source['region']!,
                      style: TextStyle(
                        fontSize: 10,
                        color: source['region'] == '国内' ? Colors.green : AppTheme.primaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _downloadSource = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDownloadProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在下载: ${_currentDownloadFile ?? ""}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceOf(context),
                    ),
                  ),
                  Text(
                    _currentProgressText,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(_currentProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _currentProgress,
            backgroundColor: AppTheme.onSurfaceOf(context).withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOf(context)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        ...AppConstants.supertonicDownloadableFiles.map((file) {
          final progress = _fileProgresses[file];
          return _buildFileProgressItem(file, progress);
        }),
      ],
    );
  }

  Widget _buildFileProgressItem(String file, DownloadProgress? progress) {
    IconData icon;
    Color iconColor;
    String statusLabel = '';

    if (progress == null) {
      if (_missingDownloadableFiles.contains(file)) {
        icon = Icons.pending;
        iconColor = AppTheme.onSurfaceOf(context).withValues(alpha: 0.4);
        statusLabel = '待下载';
      } else {
        icon = Icons.check_circle;
        iconColor = Colors.green;
        statusLabel = '已完成';
      }
    } else {
      switch (progress.status) {
        case DownloadStatus.completed:
          icon = Icons.check_circle;
          iconColor = Colors.green;
          statusLabel = '已完成';
          break;
        case DownloadStatus.downloading:
          icon = Icons.downloading;
          iconColor = AppTheme.primaryOf(context);
          statusLabel = '${(progress.progress * 100).toInt()}%';
          break;
        case DownloadStatus.failed:
          icon = Icons.error;
          iconColor = AppTheme.errorOf(context);
          statusLabel = '失败';
          break;
        case DownloadStatus.cancelled:
          icon = Icons.cancel;
          iconColor = AppTheme.errorOf(context);
          statusLabel = '取消';
          break;
        default:
          icon = Icons.pending;
          iconColor = AppTheme.onSurfaceOf(context).withValues(alpha: 0.4);
          statusLabel = '待下载';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.8),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '需下载文件 (~377MB)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceOf(context),
          ),
        ),
        const SizedBox(height: 8),
        ...AppConstants.supertonicDownloadableFiles.map((file) {
          final isMissing = _missingDownloadableFiles.contains(file);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  isMissing ? Icons.pending : Icons.check_circle,
                  color: isMissing
                      ? AppTheme.onSurfaceOf(context).withValues(alpha: 0.4)
                      : Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMissing
                        ? AppTheme.onSurfaceOf(context).withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMissing ? '待下载' : '已完成',
                    style: TextStyle(
                      fontSize: 10,
                      color: isMissing
                          ? AppTheme.onSurfaceOf(context).withValues(alpha: 0.6)
                          : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildManageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '管理模型',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.onSurfaceOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.folder, color: AppTheme.primaryOf(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _targetPath,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Semantics(
                    label: '复制路径',
                    button: true,
                    child: IconButton(
                      icon: Icon(Icons.copy, color: AppTheme.primaryOf(context)),
                      onPressed: _copyPath,
                      tooltip: '复制路径',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '大小: ${SupertonicModelService.instance.formatSize(_modelsSize)}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkModels,
                      icon: const Icon(Icons.refresh),
                      label: const Text('验证'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOf(context).withValues(alpha: 0.85),
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deleteModels,
                      icon: const Icon(Icons.delete),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}