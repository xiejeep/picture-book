import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/ai_settings_model.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_util.dart';
import '../../core/utils/platform_utils.dart';

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
      _useGlmTts = PlatformUtils.isMacOS ? true : (settings?.useGlmTts ?? false);
      _selectedTtsVoice = settings?.ttsVoice ?? AppConstants.defaultTtsVoice;
      final voiceExists =
          AppConstants.ttsVoices.any((v) => v['name'] == _selectedTtsVoice);
      _selectedTtsVoice =
          voiceExists ? _selectedTtsVoice : AppConstants.defaultTtsVoice;

      if (settings?.speechRate != null && settings!.speechRate > 0) {
        _speechRate = settings.speechRate;
      } else if (settings?.useSlowSpeed == true) {
        _speechRate = _useGlmTts
            ? AppConstants.glmTtsDefaultSpeed * 0.75
            : AppConstants.systemTtsDefaultSpeed * 0.6;
      } else {
        _speechRate = _useGlmTts
            ? AppConstants.glmTtsDefaultSpeed
            : AppConstants.systemTtsDefaultSpeed;
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final currentSettings = StorageService.instance.getAiSettings();
      final settings = (currentSettings ??
              AiSettingsModel(
                selectedModel: AppConstants.defaultModel,
              ))
          .copyWith(
        useGlmTts: _useGlmTts,
        ttsVoice: _selectedTtsVoice,
        speechRate: _speechRate,
      );
      await StorageService.instance.saveAiSettings(settings);

      ToastUtil.success('语音设置已保存');
    } catch (e) {
      ToastUtil.error('保存失败: $e');
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
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(12),
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
              if (!PlatformUtils.isMacOS)
                _buildTtsOption(
                  title: '系统TTS',
                  subtitle: '使用设备自带语音引擎',
                  value: false,
                  icon: Icons.record_voice_over,
                ),
              if (!PlatformUtils.isMacOS)
                Divider(
                    height: 1, color: AppTheme.dividerColorOf(context)),
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
    final semanticsLabel = value ? 'GLM-TTS高质量语音' : '系统TTS';
    final semanticsHint = value ? '使用AI合成语音，效果更自然' : '使用设备自带语音引擎';
    return Semantics(
      label: semanticsLabel,
      hint: semanticsHint,
      button: true,
      child: InkWell(
        onTap: () {
          if (PlatformUtils.isMacOS && value == false) return;
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
                      ? AppTheme.primaryOf(context).withValues(alpha: 0.2)
                      : AppTheme.onSurfaceOf(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.primaryOf(context)
                      : AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
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
                            color: isSelected
                                ? AppTheme.onSurfaceOf(context)
                                : AppTheme.onSurfaceOf(context)
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOf(context)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '推荐',
                              style: TextStyle(
                                  color: AppTheme.accentOf(context),
                                  fontSize: 10),
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
                        color: AppTheme.mutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Radio<bool>(
                value: value,
                groupValue: _useGlmTts,
                onChanged: (v) {
                  if (PlatformUtils.isMacOS && v == false) return;
                  setState(() {
                    _useGlmTts = v!;
                    _speechRate = v
                        ? AppConstants.glmTtsDefaultSpeed
                        : AppConstants.systemTtsDefaultSpeed;
                  });
                },
                activeColor: AppTheme.primaryOf(context),
              ),
            ],
          ),
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
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: AppTheme.cardOf(context),
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
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(12),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '当前语速',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6)),
                  ),
                  Text(
                    '${(_speechRate * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _speechRate,
                min: _useGlmTts
                    ? AppConstants.glmTtsMinSpeed
                    : AppConstants.systemTtsMinSpeed,
                max: _useGlmTts
                    ? AppConstants.glmTtsMaxSpeed
                    : AppConstants.systemTtsMaxSpeed,
                divisions: _useGlmTts
                    ? AppConstants.glmTtsSpeedDivisions
                    : AppConstants.systemTtsSpeedDivisions,
                label: '${(_speechRate * 100).toInt()}%',
                onChanged: (value) {
                  setState(() => _speechRate = value);
                },
                activeColor: AppTheme.primaryOf(context),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _useGlmTts ? '慢速' : '最慢',
                    style: TextStyle(
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6),
                        fontSize: 12),
                  ),
                  Text(
                    _useGlmTts ? '快速' : '最快',
                    style: TextStyle(
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6),
                        fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _useGlmTts ? 'GLM-TTS语速范围: 50%-150%' : '系统TTS语速范围: 30%-100%',
          style: TextStyle(
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
              fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '不同语速会分别缓存音频',
          style: TextStyle(
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
              fontSize: 12),
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
          backgroundColor: AppTheme.primaryOf(context).withValues(alpha: 0.85),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
