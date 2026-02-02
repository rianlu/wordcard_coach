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
          onStatus: (status) => debugPrint('STT Status: $status'),
          onError: (errorNotification) => debugPrint('STT Error: $errorNotification'),
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
        listenFor: const Duration(seconds: 5), // Auto-stop after 5s of silence
        pauseFor: const Duration(seconds: 2), // Auto-stop pause
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
