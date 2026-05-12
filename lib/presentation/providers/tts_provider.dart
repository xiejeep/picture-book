import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/repository_providers.dart';
import '../providers/settings_provider.dart';

class TtsState {
  final bool isSpeaking;
  final String? currentText;
  final bool isInitialized;

  const TtsState({
    this.isSpeaking = false,
    this.currentText,
    this.isInitialized = false,
  });

  TtsState copyWith({
    bool? isSpeaking,
    String? currentText,
    bool? isInitialized,
  }) {
    return TtsState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentText: currentText ?? this.currentText,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class TtsNotifier extends Notifier<TtsState> {
  @override
  TtsState build() {
    return const TtsState();
  }

  Future<void> initialize() async {
    await ref.read(ttsRepositoryProvider).initialize();
    state = state.copyWith(isInitialized: true);
  }

  Future<void> speak(String text) async {
    state = state.copyWith(isSpeaking: true, currentText: text);
    try {
      await ref.read(ttsRepositoryProvider).speak(text);
    } finally {
      state = state.copyWith(isSpeaking: false, currentText: null);
    }
  }

  Future<void> stop() async {
    await ref.read(ttsRepositoryProvider).stop();
    state = state.copyWith(isSpeaking: false, currentText: null);
  }

  Future<void> setSpeechRate(double rate) async {
    await ref.read(ttsRepositoryProvider).setSpeechRate(rate);
  }

  void dispose() {
    ref.read(ttsRepositoryProvider).dispose();
  }
}

final ttsProvider = NotifierProvider<TtsNotifier, TtsState>(() {
  return TtsNotifier();
});

final isSpeakingProvider = Provider<bool>((ref) {
  return ref.watch(ttsProvider).isSpeaking;
});