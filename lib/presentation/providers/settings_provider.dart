import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ai_settings_model.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/nfc_service.dart';
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
    try {
      final storage = StorageService.instance;
      final settings = storage.getAiSettings();
      final hasKey = await ref.read(aiRepositoryProvider).hasApiKey();

      state = SettingsState(
        settings: settings,
        hasApiKey: hasKey,
        isLoading: false,
      );
    } catch (_) {
      state = const SettingsState(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await _loadSettings();
  }

  Future<bool> testConnection(String apiKey, String model) async {
    return await ref.read(aiRepositoryProvider).testConnection(apiKey, model);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

final hasApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).hasApiKey;
});

final selectedModelProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).settings?.selectedModel ??
      AppConstants.defaultModel;
});

final selectedTextModelProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).settings?.selectedTextModel ??
      AppConstants.defaultTextModel;
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return StorageService.instance.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await StorageService.instance.saveThemeMode(mode);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

final nfcAvailableProvider = FutureProvider<bool>((ref) async {
  return await NfcService.instance.isAvailable();
});

final nfcEnabledProvider = NotifierProvider<NfcEnabledNotifier, bool>(() {
  return NfcEnabledNotifier();
});

class NfcEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return StorageService.instance.getNfcEnabled();
  }

  Future<void> setNfcEnabled(bool enabled) async {
    await StorageService.instance.saveNfcEnabled(enabled);
    state = enabled;
  }
}
