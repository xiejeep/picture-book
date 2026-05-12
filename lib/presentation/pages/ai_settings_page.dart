import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/tts_cache_service.dart';
import '../../data/models/ai_settings_model.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedModel = AppConstants.defaultModel;
  String _selectedTtsVoice = AppConstants.defaultTtsVoice;
  double _speechRate = AppConstants.systemTtsDefaultSpeed;
  bool _useGlmTts = false;
  bool _obscureApiKey = true;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _hasExistingKey = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await AiService.instance.getApiKey();
    final settings = StorageService.instance.getAiSettings();

    setState(() {
      if (apiKey != null && apiKey.isNotEmpty) {
        _apiKeyController.text = apiKey;
        _hasExistingKey = true;
      }
      
      final savedModel = settings?.selectedModel ?? AppConstants.defaultModel;
      final modelExists = AppConstants.availableModels.any((m) => m['name'] == savedModel);
      _selectedModel = modelExists ? savedModel : AppConstants.defaultModel;
      
      _useGlmTts = settings?.useGlmTts ?? false;
      _selectedTtsVoice = settings?.ttsVoice ?? AppConstants.defaultTtsVoice;
      final voiceExists = AppConstants.ttsVoices.any((v) => v['name'] == _selectedTtsVoice);
      _selectedTtsVoice = voiceExists ? _selectedTtsVoice : AppConstants.defaultTtsVoice;
      
      if (settings?.speechRate != null && settings!.speechRate > 0) {
        _speechRate = settings.speechRate;
      } else if (settings?.useSlowSpeed == true) {
        _speechRate = _useGlmTts ? AppConstants.glmTtsDefaultSpeed * 0.75 : AppConstants.systemTtsDefaultSpeed * 0.6;
      } else {
        _speechRate = _useGlmTts ? AppConstants.glmTtsDefaultSpeed : AppConstants.systemTtsDefaultSpeed;
      }
    });
  }

  Future<void> _saveSettings() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入API Key'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await AiService.instance.saveApiKey(_apiKeyController.text);

      final settings = AiSettingsModel(
        selectedModel: _selectedModel,
        useGlmTts: _useGlmTts,
        ttsVoice: _selectedTtsVoice,
        speechRate: _speechRate,
      );
      await StorageService.instance.saveAiSettings(settings);

      setState(() => _hasExistingKey = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final success = await AiService.instance.testConnection(
        _apiKeyController.text,
        _selectedModel,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '连接成功！' : '连接失败，请检查API Key'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('测试失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _deleteApiKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除已保存的API Key吗？删除后需要重新配置才能使用AI功能。'),
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
      await AiService.instance.deleteApiKey();
      await StorageService.instance.deleteAiSettings();
      
      setState(() {
        _apiKeyController.clear();
        _hasExistingKey = false;
        _selectedModel = AppConstants.defaultModel;
        _useGlmTts = false;
        _selectedTtsVoice = AppConstants.defaultTtsVoice;
        _speechRate = AppConstants.systemTtsDefaultSpeed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key已删除'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI设置'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.gentleGreen,
                AppTheme.calmBlue,
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.warmGradientBox,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildApiKeySection(),
                const SizedBox(height: 24),
                _buildModelSection(),
                const SizedBox(height: 24),
                _buildTtsSection(),
                const SizedBox(height: 24),
                _buildCacheSection(),
                const SizedBox(height: 32),
                _buildButtonsSection(),
                const SizedBox(height: 24),
                _buildInfoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '智谱AI API Key',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_hasExistingKey)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '已配置',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: '请输入智谱AI API Key',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscureApiKey = !_obscureApiKey);
                  },
                ),
                if (_hasExistingKey)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _deleteApiKey,
                    tooltip: '删除API Key',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            children: [
              const TextSpan(text: 'API Key可在 '),
              TextSpan(
                text: 'open.bigmodel.cn',
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse('https://www.bigmodel.cn/glm-coding?ic=PP52KPSJX5');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
              ),
              const TextSpan(text: ' 获取'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择模型',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedModel,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: AppConstants.availableModels.map((model) {
            return DropdownMenuItem(
              value: model['name'],
              child: Text(model['label']!),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedModel = value);
            }
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Flash模型免费，FlashX/Turbo/GLM-4V需付费',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTtsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '语音设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              '使用GLM-TTS高质量语音',
              style: TextStyle(fontSize: 14),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '推荐',
                style: TextStyle(color: Colors.orange, fontSize: 10),
              ),
            ),
            const Spacer(),
            Switch(
              value: _useGlmTts,
              onChanged: (value) {
                setState(() {
                  _useGlmTts = value;
                  _speechRate = value 
                      ? AppConstants.glmTtsDefaultSpeed 
                      : AppConstants.systemTtsDefaultSpeed;
                });
              },
            ),
          ],
        ),
        if (_useGlmTts) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '使用AI语音时，您的文本将发送给第三方AI服务商（智谱AI）进行处理。',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_useGlmTts) ...[
          const Text(
            'GLM-TTS音色',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTtsVoice,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: AppConstants.ttsVoices.map((voice) {
              return DropdownMenuItem(
                value: voice['name'],
                child: Text(voice['label']!),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedTtsVoice = value);
              }
            },
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          '语速选择',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _speechRate,
          min: _useGlmTts ? AppConstants.glmTtsMinSpeed : AppConstants.systemTtsMinSpeed,
          max: _useGlmTts ? AppConstants.glmTtsMaxSpeed : AppConstants.systemTtsMaxSpeed,
          divisions: _useGlmTts ? AppConstants.glmTtsSpeedDivisions : AppConstants.systemTtsSpeedDivisions,
          label: '${(_speechRate * 100).toInt()}%',
          onChanged: (value) {
            setState(() => _speechRate = value);
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _useGlmTts ? '慢速' : '最慢',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              _useGlmTts ? '快速' : '最快',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '当前语速: ${(_speechRate * 100).toInt()}%',
          style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          _useGlmTts 
              ? 'GLM-TTS语速范围: 50%-150%' 
              : '系统TTS语速范围: 30%-100%',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          '不同语速会分别缓存音频',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCacheSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getCacheInfo(),
      builder: (context, snapshot) {
        final cacheSize = snapshot.data?['size'] ?? 0;
        final fileCount = snapshot.data?['count'] ?? 0;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'TTS缓存管理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (cacheSize > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(cacheSize / 1024 / 1024).toStringAsFixed(1)}MB',
                      style: const TextStyle(color: Colors.blue, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '缓存音频文件: $fileCount 个，节省API调用',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: cacheSize > 0 ? _clearCache : null,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('清空缓存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '相同文本+音色+语速组合会缓存音频，避免重复调用API',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getCacheInfo() async {
    final size = await TtsCacheService.instance.getCacheSize();
    final count = await TtsCacheService.instance.getCacheFileCount();
    return {'size': size, 'count': count};
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
      await TtsCacheService.instance.clearCache();
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TTS缓存已清空'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Widget _buildButtonsSection() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? '保存中...' : '保存设置'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(_isTesting ? '测试中...' : '测试连接'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  '功能说明',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'AI强化识别功能可以：',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              '• 去除音标符号（如 /æ/, /ɪ/ 等）',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            Text(
              '• 去除序号标记（如 1., 2., ③ 等）',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            Text(
              '• 去除装饰符号（如 ##, |, **, → 等）',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            Text(
              '• 保留纯净的英文单词或句子',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            Text(
              '• 提升点读体验，更适合儿童学习',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
    );
  }
}