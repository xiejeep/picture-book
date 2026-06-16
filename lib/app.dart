import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/nfc_service.dart';
import 'data/services/tts_service.dart';
import 'data/services/file_intent_service.dart';
import 'presentation/providers/settings_provider.dart';

class BookApp extends ConsumerStatefulWidget {
  const BookApp({super.key});

  @override
  ConsumerState<BookApp> createState() => _BookAppState();
}

class _BookAppState extends ConsumerState<BookApp> with WidgetsBindingObserver {
  StreamSubscription<NfcAction>? _nfcSubscription;
  bool _nfcInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TtsService.instance.initialize();
    FileIntentService.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isIOS) return;
    final nfcEnabled = ref.read(nfcEnabledProvider);
    if (!nfcEnabled || !_nfcInitialized) return;

    if (state == AppLifecycleState.paused) {
      debugPrint('NFC [LIFECYCLE]: app paused, stopping NFC');
      NfcService.instance.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('NFC [LIFECYCLE]: app resumed, starting NFC');
      NfcService.instance.startForegroundListening();
    }
  }

  void _initNfcIfNeeded() {
    final nfcEnabled = ref.read(nfcEnabledProvider);
    debugPrint('NFC [LIFECYCLE]: _initNfcIfNeeded nfcEnabled=$nfcEnabled _nfcInitialized=$_nfcInitialized');
    if (nfcEnabled && !_nfcInitialized) {
      _initNfcListener();
      _nfcInitialized = true;
    }
  }

  void _stopNfcIfNeeded() {
    debugPrint('NFC [LIFECYCLE]: _stopNfcIfNeeded _nfcInitialized=$_nfcInitialized');
    if (_nfcInitialized) {
      NfcService.instance.stopListening();
      _nfcSubscription?.cancel();
      _nfcSubscription = null;
      _nfcInitialized = false;
    }
  }

  void _initNfcListener() {
    debugPrint('NFC [LIFECYCLE]: _initNfcListener starting');
    if (!Platform.isIOS) {
      NfcService.instance.startForegroundListening();
    }
    _nfcSubscription = NfcService.instance.onTagDetected.listen((action) {
      if (!mounted) return;
      if (NfcService.instance.isLastActionConsumed) return;
      final router = ref.read(goRouterProvider);
      final matches = router.routerDelegate.currentConfiguration.matches;
      final targetPath = '/book/${action.bookId}';

      int targetIndex = -1;
      for (int i = 0; i < matches.length; i++) {
        if (matches[i].matchedLocation.startsWith(targetPath)) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex >= 0) {
        final isCurrentPage = targetIndex == matches.length - 1;
        if (isCurrentPage) {
          NfcService.instance.markActionConsumed();
          return;
        }
        final popsNeeded = matches.length - 1 - targetIndex;
        for (int i = 0; i < popsNeeded; i++) {
          router.pop();
        }
      } else {
        router.push(nfcPlayRoute(action));
      }
    });
    NfcService.instance.initIntentListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nfcSubscription?.cancel();
    NfcService.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final nfcEnabled = ref.watch(nfcEnabledProvider);

    if (nfcEnabled && !_nfcInitialized) {
      Future.microtask(() => _initNfcIfNeeded());
    } else if (!nfcEnabled && _nfcInitialized) {
      Future.microtask(() => _stopNfcIfNeeded());
    }

    return MaterialApp.router(
      title: '点读鸭',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
