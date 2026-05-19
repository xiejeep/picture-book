import 'package:flutter/material.dart';
import '../../data/services/tts_cache_service.dart';
import '../../data/services/translation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_util.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/platform_utils.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  int _cacheSize = 0;
  int _fileCount = 0;
  bool _isLoading = true;
  bool _isClearing = false;
  bool _isTranslationModelDownloaded = false;
  bool _isDeletingModel = false;
  bool _isCheckingModel = true;

  @override
  void initState() {
    super.initState();
    _loadAllInfo();
  }

  Future<void> _loadAllInfo() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      TtsCacheService.instance.getCacheSize(),
      TtsCacheService.instance.getCacheFileCount(),
      PlatformUtils.supportsMlKit
          ? TranslationService.instance.isModelDownloaded()
          : Future.value(false),
    ]);
    setState(() {
      _cacheSize = results[0] as int;
      _fileCount = results[1] as int;
      _isTranslationModelDownloaded = results[2] as bool;
      _isLoading = false;
      _isCheckingModel = false;
    });
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空TTS音频缓存吗？清空后再次点读会重新调用API。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isClearing = true);
      await TtsCacheService.instance.clearCache();
      await _loadAllInfo();
      setState(() => _isClearing = false);

      ToastUtil.info('TTS缓存已清空');
    }
  }

  Future<void> _deleteTranslationModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除翻译模型'),
        content: const Text('删除后下次翻译时会重新下载模型（约30MB）。确定删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeletingModel = true);
      final deleted = await TranslationService.instance.deleteModel();
      setState(() {
        _isDeletingModel = false;
        if (deleted) {
          _isTranslationModelDownloaded = false;
        }
      });
      if (deleted) {
        ToastUtil.success('翻译模型已删除');
      } else {
        ToastUtil.error('删除失败');
      }
    }
  }

  String _formatSize(int bytes) => FileUtils.formatFileSize(bytes);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradientOf(context),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBoxOf(context),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryOf(context)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCacheInfoCard(),
                      const SizedBox(height: 24),
                      _buildCacheDetailCard(),
                      const SizedBox(height: 24),
                      if (PlatformUtils.supportsMlKit)
                        _buildTranslationModelCard(),
                      if (PlatformUtils.supportsMlKit)
                        const SizedBox(height: 24),
                      _buildClearButton(),
                      const SizedBox(height: 24),
                      _buildInfoCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCacheInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryOf(context).withValues(alpha: 0.8),
            AppTheme.calmBlue.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.audio_file_rounded,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            _formatSize(_cacheSize),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '缓存占用空间',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheDetailCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailItem(
            icon: Icons.folder_rounded,
            title: '缓存文件数量',
            value: '$_fileCount 个',
          ),
          Divider(height: 1, color: AppTheme.dividerColorOf(context)),
          _buildDetailItem(
            icon: Icons.storage_rounded,
            title: '缓存总大小',
            value: _formatSize(_cacheSize),
          ),
          Divider(height: 1, color: AppTheme.dividerColorOf(context)),
          _buildDetailItem(
            icon: Icons.info_outline_rounded,
            title: '缓存状态',
            value: _cacheSize > 0 ? '已有缓存' : '无缓存',
            trailing: _cacheSize > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.secondaryOf(context).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '正常',
                      style: TextStyle(
                        color: AppTheme.secondaryOf(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationModelCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.calmBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.translate, color: AppTheme.calmBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '翻译模型 (英→中)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onSurfaceOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isCheckingModel
                            ? '检查中...'
                            : _isTranslationModelDownloaded
                                ? '已下载，约 30MB'
                                : '未下载',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.onSurfaceOf(context)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTranslationModelDownloaded && !_isDeletingModel)
                  TextButton(
                    onPressed: _deleteTranslationModel,
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorOf(context)),
                    child: const Text('删除', style: TextStyle(fontSize: 13)),
                  ),
                if (_isDeletingModel)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryOf(context)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentOf(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppTheme.accentOf(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '删除后下次翻译时会自动重新下载',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceOf(context)
                              .withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.secondaryOf(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.secondaryOf(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceOf(context),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildClearButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_cacheSize > 0 && !_isClearing) ? _clearCache : null,
        icon: _isClearing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.delete_sweep),
        label: Text(_isClearing ? '清空中...' : '清空TTS缓存'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _cacheSize > 0
              ? AppTheme.errorOf(context)
              : AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
          foregroundColor: Theme.of(context).colorScheme.onError,
          disabledBackgroundColor:
              AppTheme.onSurfaceOf(context).withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.calmBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.calmBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                '缓存说明',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.calmBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('TTS缓存：相同文本+音色+语速组合会缓存音频'),
          const SizedBox(height: 8),
          if (PlatformUtils.supportsMlKit) ...[
            _buildInfoItem('翻译模型：离线英译中模型，首次翻译时自动下载'),
            const SizedBox(height: 8),
          ],
          _buildInfoItem('清空缓存后再次点读会重新生成音频'),
          const SizedBox(height: 8),
          _buildInfoItem('OCR识别模型由系统管理，无法手动清理'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.calmBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
