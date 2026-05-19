import 'package:hive/hive.dart';
import '../../core/constants/constants.dart';

part 'ai_settings_model.g.dart';

@HiveType(typeId: 3)
class AiSettingsModel extends HiveObject {
  @HiveField(0)
  String selectedModel;

  @HiveField(1)
  bool useGlmTts;

  @HiveField(2)
  String ttsVoice;

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
    this.useGlmTts = false,
    this.ttsVoice = AppConstants.defaultTtsVoice,
    this.speechRate = 0.5,
    this.useSlowSpeed = false,
    String? selectedTextModel,
    String? ttsEngine,
    String? supertonicVoice,
    int? supertonicSteps,
  })  : selectedTextModel = selectedTextModel ?? AppConstants.defaultTextModel,
        ttsEngine = ttsEngine ?? 'glm',
        supertonicVoice = supertonicVoice ?? AppConstants.supertonicDefaultVoice,
        supertonicSteps = supertonicSteps ?? AppConstants.supertonicDefaultSteps;

  AiSettingsModel copyWith({
    String? selectedModel,
    bool? useGlmTts,
    String? ttsVoice,
    double? speechRate,
    bool? useSlowSpeed,
    String? selectedTextModel,
    String? ttsEngine,
    String? supertonicVoice,
    int? supertonicSteps,
  }) {
    return AiSettingsModel(
      selectedModel: selectedModel ?? this.selectedModel,
      useGlmTts: useGlmTts ?? this.useGlmTts,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      speechRate: speechRate ?? this.speechRate,
      useSlowSpeed: useSlowSpeed ?? this.useSlowSpeed,
      selectedTextModel: selectedTextModel ?? this.selectedTextModel,
      ttsEngine: ttsEngine ?? this.ttsEngine,
      supertonicVoice: supertonicVoice ?? this.supertonicVoice,
      supertonicSteps: supertonicSteps ?? this.supertonicSteps,
    );
  }
}
