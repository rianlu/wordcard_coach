import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:flutter/foundation.dart';

class SpeechRecognitionChunk {
  final String text;
  final bool isFinal;

  const SpeechRecognitionChunk({required this.text, required this.isFinal});
}

/// 语音识别服务
///
/// 封装了 [stt.SpeechToText] 库，提供简单的 [startListening], [stopListening], [cancel] 接口。
///
/// ## 并发控制机制 (Generation Counter)
///
/// 为了解决语音识别引擎状态异步且难以精确控制的问题，本服务引入了 [generation] (代) 的概念：
/// * 每次调用 [startListening], [stopListening], [cancel] 都会递增 [_generation]。
/// * 所有的异步操作（如初始化、权限检查、监听回调）在执行前都会检查当前的 logic generation 是否与调用时一致。
/// * 如果不一致，说明在此期间发生了新的操作（如用户快速点击了停止又点击开始），则直接丢弃旧操作的结果。
///
/// 这种机制实现了“无锁”的并发安全，避免了旧的异步任务干扰新的识别会话。
class SpeechService {
  // 单例模式实现
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  /// 内部使用的语音识别对象
  stt.SpeechToText _speech = stt.SpeechToText();

  /// 标记服务是否已成功初始化并可用
  bool _isAvailable = false;

  /// 解析后的最终 Locale ID (例如 'en_GB' 或 'en_US')
  ///
  /// 在初始化时根据系统语言和支持列表自动确定。
  String? _resolvedLocaleId;

  /// 核心状态版本号 (Generation Counter)
  ///
  /// 用于使过期的异步操作链路自动失效。每次主要状态变更操作都会递增此值。
  int _generation = 0;

  /// 初始化任务的缓存 Future
  ///
  /// 用于防止多个并发调用触发多次初始化，保证共享同一个初始化过程。
  Future<bool>? _initFuture;

  /// 当前是否正在监听用户说话
  bool get isListening => _speech.isListening;

  /// 服务是否可用
  bool get isAvailable => _isAvailable;

  /// 检查麦克风权限状态
  Future<bool> hasPermission() async => await _speech.hasPermission;

  /// 监听状态流控制器
  ///
  /// 向外部广播当前的监听状态 (true: 正在监听, false: 停止/空闲)
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();

  /// 获取监听状态流
  Stream<bool> get listeningState => _listeningController.stream;

  // ────────────────────────────────────────────────────────────────────────
  // 初始化逻辑
  // ────────────────────────────────────────────────────────────────────────

  /// 确保语音识别引擎已初始化
  ///
  /// 如果服务已经可用，立即返回 true。
  /// 否则触发初始化流程，并确保并发调用时只执行一次初始化。
  Future<bool> ensureInitialized() {
    if (_isAvailable) return Future.value(true);
    // 如果_initFuture不为空，说明正在初始化中，直接返回该Future
    return _initFuture ??= _doInit();
  }

  /// 执行实际的初始化逻辑
  Future<bool> _doInit() async {
    debugPrint('STT: Initializing...');
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT Status: $status');
          // 根据引擎状态更新内部流状态
          if (status == 'listening') {
            _listeningController.add(true);
          } else if (status == 'notListening' || status == 'done') {
            _listeningController.add(false);
          }
        },
        onError: (errorNotification) {
          debugPrint('STT Error: ${errorNotification.errorMsg}');
          // 发生错误时，视为停止监听
          _listeningController.add(false);
        },
      );

      if (_isAvailable) {
        await _resolveLocaleId();

        // 双重检查权限，因为 initialize 可能成功但没权限 (取决于平台行为)
        final permitted = await _speech.hasPermission;
        if (!permitted) {
          debugPrint('STT: No microphone permission after init');
          _isAvailable = false;
        }
      }
      debugPrint('STT: Init result = $_isAvailable');
    } catch (e) {
      debugPrint('STT: Init failed: $e');
      _isAvailable = false;
    }

    _initFuture = null; // 清除Future缓存，允许后续重试
    return _isAvailable;
  }

  /// 确定最佳的识别语言 Locale
  ///
  /// 优先顺序:
  /// 1. en_GB (英式英语) - 强匹配
  /// 2. en-GB (英式英语) - 备选格式
  /// 3. en_US (美式英语) - 备选
  /// 4. 系统当前语言或列表第一个默认语言
  Future<void> _resolveLocaleId() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return;

      if (locales.any((l) => l.localeId == 'en_GB')) {
        _resolvedLocaleId = 'en_GB';
      } else if (locales.any((l) => l.localeId == 'en-GB')) {
        _resolvedLocaleId = 'en-GB';
      } else if (locales.any((l) => l.localeId == 'en_US')) {
        _resolvedLocaleId = 'en_US';
      } else if (locales.any((l) => l.localeId == 'en-US')) {
        _resolvedLocaleId = 'en-US';
      } else if (locales.any(
        (l) => l.localeId.toLowerCase().startsWith('en'),
      )) {
        _resolvedLocaleId = locales
            .firstWhere((l) => l.localeId.toLowerCase().startsWith('en'))
            .localeId;
      } else {
        final systemLocale = await _speech.systemLocale();
        _resolvedLocaleId = systemLocale?.localeId ?? locales.first.localeId;
      }
      debugPrint('STT: Resolved locale = $_resolvedLocaleId');
    } catch (e) {
      debugPrint('STT: Locale resolve failed: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 识别流程控制
  // ────────────────────────────────────────────────────────────────────────

  /// 启动语音识别
  ///
  /// [onResult] 识别结果回调，包含文本与是否最终结果。
  /// [onError] 发生错误时的回调，参数为错误描述信息。
  /// [localeId] 可选，指定特定的语言 ID。如果未指定，将使用 [_resolveLocaleId] 确定的默认值。
  ///
  /// 返回值: Future<bool> 表示是否成功启动了监听。
  Future<bool> startListening({
    required Function(SpeechRecognitionChunk) onResult,
    Function(String)? onError,
    String? localeId,
  }) async {
    // 捕获当前操作的 generation，用于后续校验一致性
    final myGen = ++_generation;
    debugPrint('STT: startListening (gen=$myGen)');

    // 1. 如果当前正在监听，先停止，避免冲突
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      // 这里的延时是为了让底层引擎有时间完成状态切换
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 检查是否有新操作插队
    if (myGen != _generation) return false;

    // 2. 确保服务可用
    if (!_isAvailable) {
      final ok = await ensureInitialized();
      if (myGen != _generation) return false;

      if (!ok) {
        // 如果初始化失败，尝试重置引擎并重试一次
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

    // 3. 检查麦克风权限
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

    // 4. 调用底层 API 开始监听
    try {
      final targetLocale = localeId ?? _resolvedLocaleId;
      await _speech.listen(
        onResult: (val) {
          // 仅当 generation 匹配时才处理结果，防止将旧 session 的结果回调给新 session
          if (myGen == _generation) {
            onResult(
              SpeechRecognitionChunk(
                text: val.recognizedWords,
                isFinal: val.finalResult,
              ),
            );
          }
        },
        localeId: targetLocale,
        // 超时设置：最长听 20 秒，静音 6 秒则自动结束
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 6),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
        ),
      );

      // 如果在 listen 返回的过程中发生了 cancel/stop (generation 变化)，则立即停止
      if (myGen != _generation) {
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
      _isAvailable = false; // 标记出错，下次需重新初始化
      onError?.call('Failed to start speech recognition');
      return false;
    }
  }

  /// 停止识别
  ///
  /// 这会告诉引擎停止接收音频，但会处理并交付已经接收到的音频的识别结果。
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

  /// 取消识别
  ///
  /// 立即停止识别，并且**不会**交付任何识别结果。
  /// 调用此方法后，之前所有正在进行的 startListening 流程都会因为 generation 不匹配而失效。
  Future<void> cancel() async {
    _generation++;
    debugPrint('STT: Cancel (gen=$_generation)');
    _listeningController.add(false);

    try {
      // 设定超时防止 cancel 卡死
      await _speech.cancel().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('STT: Cancel error/timeout: $e');
    }
  }

  /// 销毁服务，关闭流控制器
  void dispose() {
    _listeningController.close();
  }
}
