import 'package:book_app/core/constants/constants.dart';
import 'package:book_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReaderVoiceSettingsDialog extends StatefulWidget {
  final String engine;
  final double speechRate;
  final VoidCallback onMoreSettings;
  final Future<void> Function(double speechRate) onSave;

  const ReaderVoiceSettingsDialog({
    super.key,
    required this.engine,
    required this.speechRate,
    required this.onMoreSettings,
    required this.onSave,
  });

  @override
  State<ReaderVoiceSettingsDialog> createState() =>
      _ReaderVoiceSettingsDialogState();
}

class _ReaderVoiceSettingsDialogState extends State<ReaderVoiceSettingsDialog> {
  late double _dialogRate;

  bool get _isSupertonic => widget.engine == 'supertonic';
  double get _minSpeed => _isSupertonic
      ? AppConstants.supertonicMinSpeed
      : AppConstants.systemTtsMinSpeed;
  double get _maxSpeed => _isSupertonic
      ? AppConstants.supertonicMaxSpeed
      : AppConstants.systemTtsMaxSpeed;
  int get _speedDivisions => _isSupertonic
      ? AppConstants.supertonicSpeedDivisions
      : AppConstants.systemTtsSpeedDivisions;

  @override
  void initState() {
    super.initState();
    _dialogRate = widget.speechRate.clamp(_minSpeed, _maxSpeed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildRateSummary(context),
            const SizedBox(height: 16),
            Slider(
              value: _dialogRate,
              min: _minSpeed,
              max: _maxSpeed,
              divisions: _speedDivisions,
              activeColor: AppTheme.primaryOf(context),
              onChanged: (value) {
                setState(() => _dialogRate = value);
              },
            ),
            const SizedBox(height: 8),
            _buildSpeedLabels(context),
            const SizedBox(height: 16),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.record_voice_over_rounded,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '语音设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.onSurfaceOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRateSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _isSupertonic
                  ? AppTheme.accentOf(context).withValues(alpha: 0.2)
                  : AppTheme.primaryOf(context).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _isSupertonic ? 'Supertonic' : '系统TTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isSupertonic
                    ? AppTheme.accentOf(context)
                    : AppTheme.primaryOf(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '语速',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            '${(_dialogRate * 100).toInt()}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedLabels(BuildContext context) {
    final labelStyle = TextStyle(
      color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
      fontSize: 12,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('慢速', style: labelStyle),
        Text('快速', style: labelStyle),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onMoreSettings();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor:
                  AppTheme.primaryOf(context).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '更多设置',
              style: TextStyle(
                color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              await widget.onSave(_dialogRate);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppTheme.primaryOf(context).withValues(alpha: 0.85),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('确定'),
          ),
        ),
      ],
    );
  }
}
