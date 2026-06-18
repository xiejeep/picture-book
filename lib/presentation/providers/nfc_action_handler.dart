import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/app_router.dart';
import '../../data/services/nfc_service.dart';

final pendingNfcActionProvider = StateProvider<NfcAction?>((ref) => null);

final nfcActionHandlerProvider = Provider<NfcActionHandler>((ref) {
  return NfcActionHandler(ref);
});

class NfcActionHandler {
  final Ref _ref;

  NfcActionHandler(this._ref);

  Future<void> handle(NfcAction action) async {
    final router = _ref.read(goRouterProvider);
    final matches = router.routerDelegate.currentConfiguration.matches;
    final targetPath = '/book/${action.bookId}';

    for (int i = 0; i < matches.length; i++) {
      if (matches[i].matchedLocation.startsWith(targetPath)) {
        final isCurrentPage = i == matches.length - 1;
        if (isCurrentPage) {
          _ref.read(pendingNfcActionProvider.notifier).state = action;
          return;
        }
        final popsNeeded = matches.length - 1 - i;
        for (int j = 0; j < popsNeeded; j++) {
          router.pop();
        }
        _ref.read(pendingNfcActionProvider.notifier).state = action;
        return;
      }
    }

    router.push(nfcPlayRoute(action));
  }
}
