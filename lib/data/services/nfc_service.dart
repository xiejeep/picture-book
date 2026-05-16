import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

class NfcAction {
  final String bookId;
  final String pageId;
  final String blockId;

  const NfcAction({
    required this.bookId,
    required this.pageId,
    required this.blockId,
  });

  static const String scheme = 'dianduya';
  static const String host = 'play';

  static NfcAction? tryParse(String uri) {
    final match =
        RegExp(r'^dianduya://play/([^/]+)/([^/]+)/([^/]+)$').firstMatch(uri);
    if (match == null) return null;
    return NfcAction(
      bookId: _restore(match.group(1)!),
      pageId: _restore(match.group(2)!),
      blockId: _restore(match.group(3)!),
    );
  }

  static String _restore(String id) {
    if (id.length == 32 && !id.contains('-')) {
      return '${id.substring(0, 8)}-${id.substring(8, 12)}-${id.substring(12, 16)}-${id.substring(16, 20)}-${id.substring(20, 32)}';
    }
    return id;
  }

  String toUri() => '$scheme://$host/${_strip(bookId)}/${_strip(pageId)}/${_strip(blockId)}';

  static String _strip(String uuid) => uuid.replaceAll('-', '');

  @override
  String toString() =>
      'NfcAction(bookId: $bookId, pageId: $pageId, blockId: $blockId)';
}

class NfcService {
  static final NfcService _instance = NfcService._internal();
  static NfcService get instance => _instance;
  NfcService._internal();

  final _controller = StreamController<NfcAction>.broadcast();
  bool _isListening = false;
  bool _lastActionConsumed = false;
  String? _lastEmittedKey;
  DateTime? _lastEmitTime;

  static const _nfcChannel = MethodChannel('com.example.picture_book_app/nfc');

  Stream<NfcAction> get onTagDetected => _controller.stream;
  bool get isListening => _isListening;

  void markActionConsumed() => _lastActionConsumed = true;
  bool get isLastActionConsumed => _lastActionConsumed;

  void initIntentListener() {
    if (!Platform.isAndroid) return;
    _nfcChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNfcIntent') {
        _handleNfcUris(call.arguments);
      }
    });
    debugPrint('NFC [INTENT]: method channel listener initialized');
    _checkPendingNfcIntent();
  }

  Future<void> _checkPendingNfcIntent() async {
    try {
      final result = await _nfcChannel.invokeMethod<List<dynamic>>('getPendingNfcIntent');
      if (result != null && result.isNotEmpty) {
        debugPrint('NFC [INTENT]: got ${result.length} pending URI(s) from cold start');
        _handleNfcUris(result);
      }
    } catch (e) {
      debugPrint('NFC [INTENT]: no pending NFC intent: $e');
    }
  }

  void _emit(NfcAction action) {
    final key = '${action.bookId}/${action.pageId}/${action.blockId}';
    final now = DateTime.now();
    if (_lastEmittedKey == key &&
        _lastEmitTime != null &&
        now.difference(_lastEmitTime!).inMilliseconds < 1000) {
      debugPrint('NFC: duplicate action ignored: $key');
      return;
    }
    _lastEmittedKey = key;
    _lastEmitTime = now;
    _lastActionConsumed = false;
    _controller.add(action);
  }

  void _handleNfcUris(List<dynamic> uris) {
    debugPrint('NFC [INTENT]: handling ${uris.length} URI(s)');
    for (final uri in uris) {
      debugPrint('NFC [INTENT]: URI = $uri');
      final action = NfcAction.tryParse(uri);
      if (action != null) {
        debugPrint('NFC [INTENT]: parsed action: $action');
        _emit(action);
        return;
      }
      final cleanUri = uri.toString().replaceFirst(RegExp(r'^[\s\S]{2}'), '');
      final action2 = NfcAction.tryParse(cleanUri);
      if (action2 != null) {
        debugPrint('NFC [INTENT]: parsed action (cleaned): $action2');
        _emit(action2);
        return;
      }
      debugPrint('NFC [INTENT]: could not parse as NfcAction: $uri');
    }
  }

  Future<bool> isAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  }

  void startForegroundListening() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (_isListening) {
      debugPrint('NFC [READ]: restarting session (was already listening)');
      try {
        NfcManager.instance.stopSession();
      } catch (_) {}
    }

    _isListening = true;
    debugPrint('NFC [READ]: starting foreground listening session...');
    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      invalidateAfterFirstReadIos: false,
      onDiscovered: (NfcTag tag) async {
        // ignore: invalid_use_of_protected_member
        debugPrint('NFC [READ]: tag discovered, data=${tag.data}');
        _handleTag(tag);
      },
    );
    debugPrint('NFC [READ]: foreground listening started');
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    debugPrint('NFC: foreground listening stopped');
  }

  Future<void> writeTag(String bookId, String pageId, String blockId) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw NfcException('NFC not supported on this platform');
    }

    final available = await isAvailable();
    if (!available) {
      throw NfcException('NFC is not available on this device');
    }

    final completer = Completer<void>();
    final uri = NfcAction(
      bookId: bookId,
      pageId: pageId,
      blockId: blockId,
    ).toUri();

    debugPrint('NFC [WRITE]: starting write session for URI: $uri');

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        // ignore: invalid_use_of_protected_member
        debugPrint('NFC [WRITE]: tag discovered, data=${tag.data}');
        final ndef = _getNdefFromTag(tag);
        if (ndef == null) {
          debugPrint('NFC [WRITE]: tag does not support NDEF');
          await NfcManager.instance.stopSession(
            errorMessageIos: '此标签不支持 NDEF',
          );
          if (!completer.isCompleted) {
            completer.completeError(NfcException('此标签不支持 NDEF 格式'));
          }
          return;
        }

        try {
          debugPrint('NFC [WRITE]: constructing NDEF message for URI: $uri');
          final message = NdefMessage(
            records: [
              NdefRecord(
                typeNameFormat: TypeNameFormat.wellKnown,
                type: Uint8List.fromList([0x55]),
                identifier: Uint8List(0),
                payload: Uint8List.fromList(uri.codeUnits),
              ),
            ],
          );
          debugPrint('NFC [WRITE]: writing NDEF message (${message.records.length} record(s), '
              '${message.byteLength} bytes)...');
          await _writeNdef(ndef, message);
          debugPrint('NFC [WRITE]: write successful, stopping session');
          await NfcManager.instance.stopSession(
            alertMessageIos: 'NFC 标签绑定成功！',
          );
          _isListening = false;
          startForegroundListening();
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (e, stackTrace) {
          debugPrint('NFC [WRITE]: write failed: $e');
          debugPrint('NFC [WRITE]: stackTrace: $stackTrace');
          await NfcManager.instance.stopSession(
            errorMessageIos: '写入失败',
          );
          _isListening = false;
          startForegroundListening();
          if (!completer.isCompleted) {
            completer.completeError(NfcException('写入 NFC 标签失败: $e'));
          }
        }
      },
    );

    return completer.future;
  }

  dynamic _getNdefFromTag(NfcTag tag) {
    if (Platform.isAndroid) {
      final ndef = NdefAndroid.from(tag);
      debugPrint('NFC: NdefAndroid.from(tag) => ${ndef != null ? "found (type=${ndef.type}, writable=${ndef.isWritable}, maxSize=${ndef.maxSize})" : "null"}');
      return ndef;
    } else if (Platform.isIOS) {
      final ndef = NdefIos.from(tag);
      debugPrint('NFC: NdefIos.from(tag) => ${ndef != null ? "found (status=${ndef.status}, capacity=${ndef.capacity})" : "null"}');
      return ndef;
    }
    return null;
  }

  Future<void> _writeNdef(dynamic ndef, NdefMessage message) async {
    if (Platform.isAndroid && ndef is NdefAndroid) {
      await ndef.writeNdefMessage(message);
    } else if (Platform.isIOS && ndef is NdefIos) {
      await ndef.writeNdef(message);
    }
  }

  NdefMessage? _getCachedMessage(dynamic ndef) {
    if (Platform.isAndroid && ndef is NdefAndroid) {
      return ndef.cachedNdefMessage;
    } else if (Platform.isIOS && ndef is NdefIos) {
      return ndef.cachedNdefMessage;
    }
    return null;
  }

  void _handleTag(NfcTag tag) {
    debugPrint('NFC [READ]: _handleTag called');
    final ndef = _getNdefFromTag(tag);
    if (ndef == null) {
      debugPrint('NFC [READ]: tag does not support NDEF, ignoring');
      return;
    }

    final cachedMessage = _getCachedMessage(ndef);
    if (cachedMessage == null) {
      debugPrint('NFC [READ]: no cached NDEF message on tag');
      return;
    }

    debugPrint('NFC [READ]: cached NDEF message has ${cachedMessage.records.length} record(s)');
    for (int i = 0; i < cachedMessage.records.length; i++) {
      final record = cachedMessage.records[i];
      try {
        debugPrint('NFC [READ]: record[$i] tnf=${record.typeNameFormat.name}, '
            'type=${record.type}, id=${record.identifier}, '
            'payload length=${record.payload.length}');

        final payload = String.fromCharCodes(record.payload);
        debugPrint('NFC [READ]: record[$i] raw payload string: $payload');

        final action = NfcAction.tryParse(payload);
        if (action != null) {
          debugPrint('NFC [READ]: record[$i] parsed action: $action');
          _emit(action);
          return;
        }

        final cleanPayload = payload.replaceFirst(RegExp(r'^[\s\S]{2}'), '');
        debugPrint('NFC [READ]: record[$i] clean payload: $cleanPayload');
        final action2 = NfcAction.tryParse(cleanPayload);
        if (action2 != null) {
          debugPrint('NFC [READ]: record[$i] parsed action (cleaned): $action2');
          _emit(action2);
          return;
        }

        debugPrint('NFC [READ]: record[$i] could not parse as NfcAction');
      } catch (e) {
        debugPrint('NFC [READ]: record[$i] error parsing: $e');
      }
    }
  }

  void dispose() {
    stopListening();
    _controller.close();
  }
}

class NfcException implements Exception {
  final String message;
  NfcException(this.message);

  @override
  String toString() => 'NfcException: $message';
}
