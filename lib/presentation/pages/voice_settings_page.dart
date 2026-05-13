import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/ai_settings_model.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';

class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  String _selectedTtsVoice = AppConstants.defaultTtsVoice;
  double _speechRate = AppConstants.systemTtsDefaultSpeed;
  bool _useGlmTts = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = StorageService.instance.getAiSettings();

    setState(() {
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
    setState(() => _isSaving = true);

    try {
      final currentSettings = StorageService.instance.getAiSettings();
      final settings = AiSettingsModel(
        selectedModel: currentSettings?.selectedModel ?? AppConstants.defaultModel,
        useGlmTts: _useGlmTts,
        ttsVoice: _selectedTtsVoice,
        speechRate: _speechRate,
      );
      await StorageService.instance.saveAiSettings(settings);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('语音设置已保存'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音设置'),
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
                _buildTtsTypeSection(),
                const SizedBox(height: 24),
                if (_useGlmTts) _buildVoiceSection(),
                if (_useGlmTts) const SizedBox(height: 24),
                _buildSpeechRateSection(),
                const SizedBox(height: 32),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTtsTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '语音类型',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTtsOption(
                title: '系统TTS',
                subtitle: '使用设备自带语音引擎',
                value: false,
                icon: Icons.record_voice_over,
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              _buildTtsOption(
                title: 'GLM-TTS高质量语音',
                subtitle: 'AI合成语音，效果更自然',
                value: true,
                icon: Icons.auto_awesome,
                recommended: true,
              ),
            ],
          ),
        ),
        if (_useGlmTts) ...[
          const SizedBox(height: 12),
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
      ],
    );
  }

  Widget _buildTtsOption({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    bool recommended = false,
  }) {
    final isSelected = _useGlmTts == value;
    return InkWell(
      onTap: () {
        setState(() {
          _useGlmTts = value;
          _speechRate = value
              ? AppConstants.glmTtsDefaultSpeed
              : AppConstants.systemTtsDefaultSpeed;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.gentleGreen.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.gentleGreen : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
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
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: value,
              groupValue: _useGlmTts,
              onChanged: (v) {
                setState(() {
                  _useGlmTts = v!;
                  _speechRate = v
                      ? AppConstants.glmTtsDefaultSpeed
                      : AppConstants.systemTtsDefaultSpeed;
                });
              },
              activeColor: AppTheme.gentleGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GLM-TTS音色',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTtsVoice,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: Colors.white,
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
    );
  }

  Widget _buildSpeechRateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '语速设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '当前语速',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  Text(
                    '${(_speechRate * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gentleGreen,
                    ),
                  ),
                ],
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
                activeColor: AppTheme.gentleGreen,
              ),
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
            ],
          ),
        ),
        const SizedBox(height: 8),
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}