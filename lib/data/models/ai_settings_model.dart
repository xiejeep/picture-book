import 'package:hive/hive.dart';
import '../../core/constants/constants.dart';

part 'ai_settings_model.g.dart';

@HiveType(typeId: 3)
class AiSettingsModel extends HiveObject {
  @HiveField(0)
  String selectedModel;

  @HiveField(3)
  double speechRate;

  @HiveField(4)
  bool useSlowSpeed;

  @HiveField(5)
  String selectedTextModel;

  @HiveField(6)
  String ttsEngine;

  @HiveField(7)
  String supertonicVoice;

  @HiveField(8)
  int supertonicSteps;

  AiSettingsModel({
    required this.selectedModel,
    this.speechRate = 0.5,
    this.useSlowSpeed = false,
    String? selectedTextModel,
    String? ttsEngine,
    String? supertonicVoice,
    int? supertonicSteps,
  })  : selectedTextModel = selectedTextModel ?? AppConstants.defaultTextModel,
        ttsEngine = ttsEngine ?? 'system',
        supertonicVoice = supertonicVoice ?? AppConstants.supertonicDefaultVoice,
        supertonicSteps = supertonicSteps ?? AppConstants.supertonicDefaultSteps;

  AiSettingsModel copyWith({
    String? selectedModel,
    double? speechRate,
    bool? useSlowSpeed,
    String? selectedTextModel,
    String? ttsEngine,
    String? supertonicVoice,
    int? supertonicSteps,
  }) {
    return AiSettingsModel(
      selectedModel: selectedModel ?? this.selectedModel,
      speechRate: speechRate ?? this.speechRate,
      useSlowSpeed: useSlowSpeed ?? this.useSlowSpeed,
      selectedTextModel: selectedTextModel ?? this.selectedTextModel,
      ttsEngine: ttsEngine ?? this.ttsEngine,
      supertonicVoice: supertonicVoice ?? this.supertonicVoice,
      supertonicSteps: supertonicSteps ?? this.supertonicSteps,
    );
  }
}
