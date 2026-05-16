import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/nfc_service.dart';
import 'data/services/tts_service.dart';
import 'presentation/providers/settings_provider.dart';

class BookApp extends ConsumerStatefulWidget {
  const BookApp({super.key});

  @override
  ConsumerState<BookApp> createState() => _BookAppState();
}

class _BookAppState extends ConsumerState<BookApp> with WidgetsBindingObserver {
  StreamSubscription<NfcAction>? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TtsService.instance.initialize();
    _initNfcListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      NfcService.instance.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      NfcService.instance.startForegroundListening();
    }
  }

  void _initNfcListener() {
    NfcService.instance.startForegroundListening();
    _nfcSubscription = NfcService.instance.onTagDetected.listen((action) {
      if (!mounted) return;
      if (NfcService.instance.isLastActionConsumed) return;
      final router = ref.read(goRouterProvider);
      final currentPath = router.routerDelegate.currentConfiguration.uri.path;
      final targetPath = '/book/${action.bookId}';
      if (currentPath == targetPath) return;
      router.push(nfcPlayRoute(action));
    });
    NfcService.instance.initIntentListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nfcSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '点读鸭',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
