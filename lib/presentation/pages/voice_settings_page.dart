import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supertonic_model_service.dart';
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
  String _ttsEngine = 'system';
  String _supertonicVoice = AppConstants.supertonicDefaultVoice;
  int _supertonicSteps = AppConstants.supertonicDefaultSteps;
  double _speechRate = AppConstants.systemTtsDefaultSpeed;
  bool _isSaving = false;
  bool _hasSupertonicModels = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = StorageService.instance.getAiSettings();

    setState(() {
      _ttsEngine = settings?.ttsEngine ?? 'system';

      _supertonicVoice =
          settings?.supertonicVoice ?? AppConstants.supertonicDefaultVoice;
      final supertonicVoiceExists = AppConstants.supertonicVoices
          .any((v) => v['name'] == _supertonicVoice);
      _supertonicVoice = supertonicVoiceExists
          ? _supertonicVoice
          : AppConstants.supertonicDefaultVoice;

      _supertonicSteps =
          settings?.supertonicSteps ?? AppConstants.supertonicDefaultSteps;
      _supertonicSteps = _supertonicSteps.clamp(
          AppConstants.supertonicMinSteps, AppConstants.supertonicMaxSteps);

      if (settings?.speechRate != null && settings!.speechRate > 0) {
        _speechRate = settings.speechRate;
      } else {
        _speechRate = _getDefaultSpeechRate(_ttsEngine);
      }
    });

    if (PlatformUtils.supportsSupertonic && _ttsEngine == 'supertonic') {
      await _checkSupertonicModels();
    }
  }

  Future<void> _checkSupertonicModels() async {
    try {
      final hasModels = await SupertonicModelService.instance.hasAllModels();
      setState(() => _hasSupertonicModels = hasModels);

      if (!hasModels && _ttsEngine == 'supertonic') {
        setState(() {
          _ttsEngine = 'system';
          _speechRate = _getDefaultSpeechRate('system');
        });

        final currentSettings = StorageService.instance.getAiSettings();
        final settings = (currentSettings ??
                AiSettingsModel(selectedModel: AppConstants.defaultModel))
            .copyWith(
          ttsEngine: 'system',
          speechRate: _speechRate,
        );
        await StorageService.instance.saveAiSettings(settings);
        ToastUtil.info('Supertonic 模型已删除，已切换到系统语音');
      }
    } catch (e) {
      debugPrint('检查 Supertonic 模型错误: $e');
      setState(() => _hasSupertonicModels = false);
    }
  }

  double _getDefaultSpeechRate(String engine) {
    switch (engine) {
      case 'system':
        return AppConstants.systemTtsDefaultSpeed;
      case 'supertonic':
        return AppConstants.supertonicDefaultSpeed;
      default:
        return AppConstants.systemTtsDefaultSpeed;
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final currentSettings = StorageService.instance.getAiSettings();
      final settings = (currentSettings ??
              AiSettingsModel(selectedModel: AppConstants.defaultModel))
          .copyWith(
        ttsEngine: _ttsEngine,
        speechRate: _speechRate,
        supertonicVoice: _supertonicVoice,
        supertonicSteps: _supertonicSteps,
      );
      await StorageService.instance.saveAiSettings(settings);

      ToastUtil.success('语音设置已保存');
    } catch (e) {
      ToastUtil.error('保存失败: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _onTtsEngineChanged(String engine) {
    if (!PlatformUtils.supportsSupertonic && engine == 'supertonic') return;

    setState(() {
      _ttsEngine = engine;
      _speechRate = _getDefaultSpeechRate(engine);
    });
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
                if (_ttsEngine == 'supertonic') ...[
                  _buildSupertonicVoiceSection(),
                  const SizedBox(height: 24),
                  _buildSupertonicStepsSection(),
                  if (!_hasSupertonicModels) ...[
                    const SizedBox(height: 24),
                    _buildSupertonicModelWarning(),
                  ],
                ],
                if (_ttsEngine == 'supertonic')
                  const SizedBox(height: 24),
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
        Text(
          '语音类型',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.onSurfaceOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (PlatformUtils.supportsSystemTts)
                _buildTtsOption(
                  title: '系统TTS',
                  subtitle: '使用设备自带语音引擎',
                  value: 'system',
                  icon: Icons.record_voice_over,
                ),
              if (PlatformUtils.supportsSupertonic)
                Divider(height: 1, color: AppTheme.dividerColorOf(context)),
              if (PlatformUtils.supportsSupertonic)
                _buildTtsOption(
                  title: 'Supertonic本地语音',
                  subtitle: '端侧离线合成，无需网络',
                  value: 'supertonic',
                  icon: Icons.mic,
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
    required String value,
    required IconData icon,
    bool recommended = false,
  }) {
    final isSelected = _ttsEngine == value;

    return Semantics(
      label: title,
      hint: subtitle,
      button: true,
      child: InkWell(
        onTap: () => _onTtsEngineChanged(value),
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
                          fontSize: 12, color: AppTheme.mutedOf(context)),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                groupValue: _ttsEngine,
                onChanged: (v) => _onTtsEngineChanged(v!),
                activeColor: AppTheme.primaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupertonicVoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supertonic音色',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurfaceOf(context)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _supertonicVoice,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: AppTheme.cardOf(context),
          ),
          items: AppConstants.supertonicVoices.map((voice) {
            return DropdownMenuItem(
                value: voice['name'], child: Text(voice['label']!));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _supertonicVoice = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSupertonicStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '生成质量',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurfaceOf(context)),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '扩散步数',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6)),
                  ),
                  Text(
                    _supertonicSteps.toString(),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOf(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _supertonicSteps.toDouble(),
                min: AppConstants.supertonicMinSteps.toDouble(),
                max: AppConstants.supertonicMaxSteps.toDouble(),
                divisions: AppConstants.supertonicMaxSteps -
                    AppConstants.supertonicMinSteps,
                label: _supertonicSteps.toString(),
                onChanged: (value) {
                  setState(() => _supertonicSteps = value.toInt());
                },
                activeColor: AppTheme.primaryOf(context),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '快速 (低质)',
                    style: TextStyle(
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6),
                        fontSize: 12),
                  ),
                  Text(
                    '慢速 (高质)',
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
          '步数越高，音质越好，但生成速度越慢',
          style: TextStyle(
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
              fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSupertonicModelWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorOf(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.errorOf(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: AppTheme.errorOf(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '模型未下载',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.errorOf(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              await context.push('/settings/supertonic');
              _checkSupertonicModels();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOf(context),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechRateSection() {
    final minSpeed = _getMinSpeed();
    final maxSpeed = _getMaxSpeed();
    final divisions = _getSpeedDivisions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '语速设置',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurfaceOf(context)),
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
                    _ttsEngine == 'supertonic'
                        ? '${(_speechRate * 100).toInt()}%'
                        : '${(_speechRate * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOf(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _speechRate,
                min: minSpeed,
                max: maxSpeed,
                divisions: divisions,
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
                    '慢速',
                    style: TextStyle(
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6),
                        fontSize: 12),
                  ),
                  Text(
                    '快速',
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
          _getSpeedRangeHint(),
          style: TextStyle(
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
              fontSize: 12),
        ),
      ],
    );
  }

  double _getMinSpeed() {
    switch (_ttsEngine) {
      case 'system':
        return AppConstants.systemTtsMinSpeed;
      case 'supertonic':
        return AppConstants.supertonicMinSpeed;
      default:
        return AppConstants.systemTtsMinSpeed;
    }
  }

  double _getMaxSpeed() {
    switch (_ttsEngine) {
      case 'system':
        return AppConstants.systemTtsMaxSpeed;
      case 'supertonic':
        return AppConstants.supertonicMaxSpeed;
      default:
        return AppConstants.systemTtsMaxSpeed;
    }
  }

  int _getSpeedDivisions() {
    switch (_ttsEngine) {
      case 'system':
        return AppConstants.systemTtsSpeedDivisions;
      case 'supertonic':
        return AppConstants.supertonicSpeedDivisions;
      default:
        return AppConstants.systemTtsSpeedDivisions;
    }
  }

  String _getSpeedRangeHint() {
    switch (_ttsEngine) {
      case 'system':
        return '系统TTS语速范围: 10%-100%';
      case 'supertonic':
        return 'Supertonic语速范围: 50%-200%';
      default:
        return '';
    }
  }

  Widget _buildSaveButton() {
    final supertonicModelsMissing =
        _ttsEngine == 'supertonic' && !_hasSupertonicModels;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed:
            (_isSaving || supertonicModelsMissing) ? null : _saveSettings,
        icon: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.save),
        label: Text(_isSaving ? '保存中...' : '保存设置'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOf(context).withValues(alpha: 0.85),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
