import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 语音识别服务 — 基于 generation 计数器的无锁设计
///
/// 核心思想：每次 [startListening] / [stopListening] / [cancel] 都递增
/// [_generation]，所有异步回调通过比较 generation 判断自身是否已过期，
/// 从而天然避免新旧 session 交叉。
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  String? _resolvedLocaleId;

  /// 每次 start/stop/cancel 递增，用于使旧的异步链路自动失效
  int _generation = 0;

  /// 缓存 init Future，保证并发调用共享同一次初始化
  Future<bool>? _initFuture;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isAvailable;
  Future<bool> hasPermission() async => await _speech.hasPermission;

  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();
  Stream<bool> get listeningState => _listeningController.stream;

  // ──────────────── 初始化 ────────────────

  /// 确保引擎已初始化（并发安全，多次调用共享同一个 Future）
  Future<bool> ensureInitialized() {
    if (_isAvailable) return Future.value(true);
    return _initFuture ??= _doInit();
  }

  Future<bool> _doInit() async {
    debugPrint('STT: Initializing...');
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'listening') {
            _listeningController.add(true);
          } else if (status == 'notListening' || status == 'done') {
            _listeningController.add(false);
          }
        },
        onError: (errorNotification) {
          debugPrint('STT Error: ${errorNotification.errorMsg}');
          _listeningController.add(false);
        },
      );
      if (_isAvailable) {
        await _resolveLocaleId();
        final permitted = await _speech.hasPermission;
        if (!permitted) {
          debugPrint('STT: No microphone permission');
          _isAvailable = false;
        }
      }
      debugPrint('STT: Init result = $_isAvailable');
    } catch (e) {
      debugPrint('STT: Init failed: $e');
      _isAvailable = false;
    }
    _initFuture = null; // 允许下次重试
    return _isAvailable;
  }

  Future<void> _resolveLocaleId() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return;
      if (locales.any((l) => l.localeId == 'en_US')) {
        _resolvedLocaleId = 'en_US';
      } else {
        final systemLocale = await _speech.systemLocale();
        _resolvedLocaleId =
            systemLocale?.localeId ?? locales.first.localeId;
      }
      debugPrint('STT: Resolved locale = $_resolvedLocaleId');
    } catch (e) {
      debugPrint('STT: Locale resolve failed: $e');
    }
  }

  // ──────────────── 识别控制 ────────────────

  /// 启动识别。每次调用会自动使之前的调用失效。
  Future<bool> startListening({
    required Function(String) onResult,
    Function(String)? onError,
    String? localeId,
  }) async {
    final myGen = ++_generation;
    debugPrint('STT: startListening (gen=$myGen)');

    // ① 停止现有监听
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (myGen != _generation) return false;

    // ② 确保引擎初始化
    if (!_isAvailable) {
      final ok = await ensureInitialized();
      if (myGen != _generation) return false;

      if (!ok) {
        // 初始化失败，重置引擎后再试一次
        debugPrint('STT: Init failed, resetting engine...');
        try {
          await _speech.cancel();
        } catch (_) {}
        _speech = stt.SpeechToText();
        _isAvailable = false;
        _initFuture = null;
        await Future.delayed(const Duration(milliseconds: 300));
        if (myGen != _generation) return false;

        final retryOk = await ensureInitialized();
        if (myGen != _generation) return false;
        if (!retryOk) {
          onError?.call('Speech recognition not available');
          return false;
        }
      }
    }

    // ③ 检查权限
    try {
      final permitted = await _speech.hasPermission;
      if (!permitted) {
        onError?.call('Microphone permission denied');
        return false;
      }
    } catch (_) {
      onError?.call('Permission check failed');
      return false;
    }
    if (myGen != _generation) return false;

    // ④ 开始监听
    try {
      final targetLocale = localeId ?? _resolvedLocaleId;
      await _speech.listen(
        onResult: (val) {
          // generation 校验：过期回调自动丢弃
          if (myGen == _generation) {
            onResult(val.recognizedWords);
          }
        },
        localeId: targetLocale,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 6),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
        ),
      );

      if (myGen != _generation) {
        // 在 listen 返回前被 cancel，清理
        try {
          await _speech.stop();
        } catch (_) {}
        return false;
      }

      debugPrint('STT: Listening started (gen=$myGen)');
      return true;
    } catch (e) {
      debugPrint('STT: Listen error: $e');
      _listeningController.add(false);
      _isAvailable = false; // 标记不可用，下次会重新初始化
      onError?.call('Failed to start speech recognition');
      return false;
    }
  }

  /// 停止识别（会交付最终结果）
  Future<void> stopListening() async {
    _generation++;
    debugPrint('STT: Stop (gen=$_generation)');
    _listeningController.add(false);
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('STT: Stop error: $e');
      }
    }
  }

  /// 取消识别（不交付结果，使所有进行中的 startListening 失效）
  Future<void> cancel() async {
    _generation++;
    debugPrint('STT: Cancel (gen=$_generation)');
    _listeningController.add(false);
    try {
      await _speech.cancel().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('STT: Cancel error/timeout: $e');
    }
  }

  void dispose() {
    _listeningController.close();
  }
}
