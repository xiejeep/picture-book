import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ai_settings_model.dart';
import '../../data/services/storage_service.dart';
import '../../core/constants/constants.dart';
import '../providers/repository_providers.dart';

class SettingsState {
  final AiSettingsModel? settings;
  final bool hasApiKey;
  final bool isLoading;

  const SettingsState({
    this.settings,
    this.hasApiKey = false,
    this.isLoading = true,
  });

  SettingsState copyWith({
    AiSettingsModel? settings,
    bool? hasApiKey,
    bool? isLoading,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState();
  }

  Future<void> _loadSettings() async {
    final storage = StorageService.instance;
    final settings = storage.getAiSettings();
    final hasKey = await ref.read(aiRepositoryProvider).hasApiKey();
    
    state = SettingsState(
      settings: settings,
      hasApiKey: hasKey,
      isLoading: false,
    );
  }

  Future<void> saveApiKey(String apiKey) async {
    await ref.read(aiRepositoryProvider).saveApiKey(apiKey);
    await _loadSettings();
  }

  Future<void> deleteApiKey() async {
    await ref.read(aiRepositoryProvider).deleteApiKey();
    await _loadSettings();
  }

  Future<bool> testConnection(String apiKey, String model) async {
    return await ref.read(aiRepositoryProvider).testConnection(apiKey, model);
  }

  Future<void> saveSettings(AiSettingsModel settings) async {
    await StorageService.instance.saveAiSettings(settings);
    await _loadSettings();
  }

  String getSelectedModel() {
    return state.settings?.selectedModel ?? AppConstants.defaultModel;
  }

  String getTtsVoice() {
    return state.settings?.ttsVoice ?? AppConstants.defaultTtsVoice;
  }

  double getSpeechRate() {
    return state.settings?.speechRate ?? AppConstants.systemTtsDefaultSpeed;
  }

  bool useGlmTts() {
    return state.settings?.useGlmTts ?? false;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

final hasApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).hasApiKey;
});

final selectedModelProvider = Provider<String>((ref) {
  return ref.read(settingsProvider.notifier).getSelectedModel();
});