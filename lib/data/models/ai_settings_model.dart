import 'package:hive/hive.dart';

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

  AiSettingsModel({
    required this.selectedModel,
    this.useGlmTts = false,
    this.ttsVoice = 'tongtong',
    this.speechRate = 0.5,
    this.useSlowSpeed = false,
  });

  AiSettingsModel copyWith({
    String? selectedModel,
    bool? useGlmTts,
    String? ttsVoice,
    double? speechRate,
    bool? useSlowSpeed,
  }) {
    return AiSettingsModel(
      selectedModel: selectedModel ?? this.selectedModel,
      useGlmTts: useGlmTts ?? this.useGlmTts,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      speechRate: speechRate ?? this.speechRate,
      useSlowSpeed: useSlowSpeed ?? this.useSlowSpeed,
    );
  }
}