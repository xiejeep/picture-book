import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/ai_settings_model.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_util.dart';
import '../providers/settings_provider.dart';

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedModel = AppConstants.defaultModel;
  String _selectedTextModel = AppConstants.defaultTextModel;
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

      final savedTextModel = settings?.selectedTextModel ?? AppConstants.defaultTextModel;
      final textModelExists = AppConstants.availableTextModels.any((m) => m['name'] == savedTextModel);
      _selectedTextModel = textModelExists ? savedTextModel : AppConstants.defaultTextModel;
    });
  }

  Future<void> _saveSettings() async {
    if (_apiKeyController.text.isEmpty) {
      ToastUtil.error('请输入API Key');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await AiService.instance.saveApiKey(_apiKeyController.text);

      final currentSettings = StorageService.instance.getAiSettings();
      final settings = AiSettingsModel(
        selectedModel: _selectedModel,
        useGlmTts: currentSettings?.useGlmTts ?? false,
        ttsVoice: currentSettings?.ttsVoice ?? AppConstants.defaultTtsVoice,
        speechRate: currentSettings?.speechRate ?? AppConstants.systemTtsDefaultSpeed,
        selectedTextModel: _selectedTextModel,
      );
      await StorageService.instance.saveAiSettings(settings);
      await ref.read(settingsProvider.notifier).refresh();

      setState(() => _hasExistingKey = true);

      ToastUtil.success('设置已保存');
    } catch (e) {
      ToastUtil.error('保存失败: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.isEmpty) {
      ToastUtil.warning('请先输入API Key');
      return;
    }

    setState(() => _isTesting = true);

    try {
      final success = await AiService.instance.testConnection(
        _apiKeyController.text,
        _selectedModel,
      );

      if (success) {
        ToastUtil.success('连接成功！');
      } else {
        ToastUtil.error('连接失败，请检查API Key');
      }
    } catch (e) {
      ToastUtil.error('测试失败: $e');
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
      await ref.read(settingsProvider.notifier).refresh();

      setState(() {
        _apiKeyController.clear();
        _hasExistingKey = false;
        _selectedModel = AppConstants.defaultModel;
        _selectedTextModel = AppConstants.defaultTextModel;
      });

      ToastUtil.info('API Key已删除');
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
                const SizedBox(height: 16),
                _buildTextModelSection(),
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
            filled: true,
            fillColor: Colors.white,
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
          '视觉模型',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          '用于图片识别与OCR文本清洗',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedModel,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
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
      ],
    );
  }

  Widget _buildTextModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '文本模型',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          '用于结构化输出，确保JSON格式稳定',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTextModel,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          items: AppConstants.availableTextModels.map((model) {
            return DropdownMenuItem(
              value: model['name'],
              child: Text(model['label']!),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedTextModel = value);
            }
          },
        ),
      ],
    );
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gentleGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
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