import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> init() async {
    if (!_isAvailable) {
      try {
        _isAvailable = await _speech.initialize(
          onStatus: (status) {
            debugPrint('STT Status: $status');
            // Sync internal state with engine status
            if (status == 'listening') {
              _isListening = true;
            } else if (status == 'notListening' || status == 'done') {
              _isListening = false;
            }
          },
          onError: (errorNotification) {
            debugPrint('STT Error: $errorNotification');
             _isListening = false;
          },
        );
      } catch (e) {
        debugPrint("STT Initialization failed: $e");
        _isAvailable = false;
      }
    }
    return _isAvailable;
  }

  Future<void> startListening({
    required Function(String) onResult,
    String localeId = 'en_US',
  }) async {
    if (!_isAvailable) {
      bool initialized = await init();
      if (!initialized) {
          debugPrint("STT not available");
          return;
      }
    }

    if (!_isListening) {
      _isListening = true;
      await _speech.listen(
        onResult: (val) => onResult(val.recognizedWords),
        localeId: localeId,
        listenFor: const Duration(seconds: 60), // Allow up to 60s per session
        pauseFor: const Duration(seconds: 20), // Allow 20s of silence before auto-stop
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation
      );
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      _isListening = false;
      await _speech.stop();
    }
  }
}
