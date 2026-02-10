import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:flutter/foundation.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isInitializing = false; // 说明：逻辑说明
  
  // 说明：逻辑说明
  static const int _maxInitRetries = 3;
  int _initRetryCount = 0;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isAvailable;
  
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();
  Stream<bool> get listeningState => _listeningController.stream;

  /// 说明：逻辑说明
  Future<bool> init() async {
    // 说明：逻辑说明
    if (_isInitializing) {
      debugPrint('STT: Init already in progress, waiting...');
      // 说明：逻辑说明
      await Future.delayed(const Duration(milliseconds: 500));
      return _isAvailable;
    }
    
    if (_isAvailable) return true;
    
    _isInitializing = true;
    
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
      _initRetryCount = 0; // 说明：逻辑说明
    } catch (e) {
      debugPrint("STT Initialization failed: $e");
      _isAvailable = false;
    } finally {
      _isInitializing = false;
    }
    
    return _isAvailable;
  }

  /// 说明：逻辑说明
  Future<void> reset() async {
    debugPrint('STT: Force resetting engine...');
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('STT: Cancel failed during reset: $e');
    }
    
    // 说明：逻辑说明
    _speech = stt.SpeechToText();
    _isAvailable = false;
    _isInitializing = false;
    
    // 说明：逻辑说明
    await Future.delayed(const Duration(milliseconds: 300));
    await init();
  }

  /// 说明：逻辑说明
  Future<bool> startListening({
    required Function(String) onResult,
    Function(String)? onError,
    String localeId = 'en_US',
  }) async {
    // 说明：逻辑说明
    if (!_isAvailable) {
      bool initialized = await init();
      if (!initialized) {
        debugPrint("STT: Not available, cannot start listening");
        onError?.call("Speech recognition not available");
        return false;
      }
    }

    // 说明：逻辑说明
    if (_speech.isListening) {
      debugPrint('STT: Already listening, stopping first...');
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      await _speech.listen(
        onResult: (val) => onResult(val.recognizedWords),
        localeId: localeId,
        listenFor: const Duration(seconds: 30), // 说明：逻辑说明
        pauseFor: const Duration(seconds: 5), // 说明：逻辑说明
        cancelOnError: false, // 说明：逻辑说明
        listenMode: stt.ListenMode.confirmation,
      );
      debugPrint('STT: Started listening successfully');
      return true;
    } catch (e) {
      debugPrint("STT: Error starting listening: $e");
      _listeningController.add(false);
      
      // 说明：逻辑说明
      if (_initRetryCount < _maxInitRetries) {
        _initRetryCount++;
        debugPrint('STT: Retry attempt $_initRetryCount/$_maxInitRetries');
        await reset();
        return startListening(onResult: onResult, onError: onError, localeId: localeId);
      }
      
      onError?.call("Failed to start speech recognition");
      return false;
    }
  }

  /// 说明：逻辑说明
  Future<void> stopListening() async {
    if (_speech.isListening) {
      debugPrint('STT: Stopping listening...');
      _listeningController.add(false); // 说明：逻辑说明
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('STT: Error stopping: $e');
      }
    }
  }

  /// 说明：逻辑说明
  Future<void> cancel() async {
    debugPrint('STT: Cancelling...');
    _listeningController.add(false);
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('STT: Error cancelling: $e');
    }
  }

  void dispose() {
    _listeningController.close();
  }
}

