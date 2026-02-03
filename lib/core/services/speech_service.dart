import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:flutter/foundation.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  bool get isListening => _speech.isListening; // Native check is best, but we keep internal sync too
  
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();
  Stream<bool> get listeningState => _listeningController.stream;

  Future<bool> init() async {
    if (!_isAvailable) {
      try {
        _isAvailable = await _speech.initialize(
          onStatus: (status) {
            debugPrint('STT Status: $status');
            // Sync internal state with engine status
            if (status == 'listening') {
              _isListening = true;
              _listeningController.add(true); 
            } else if (status == 'notListening' || status == 'done') {
              _isListening = false;
              _listeningController.add(false);
            }
          },
          onError: (errorNotification) {
            debugPrint('STT Error: $errorNotification');
             _isListening = false;
             _listeningController.add(false);
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

    if (!_speech.isListening) {
      _isListening = true;
      try {
        await _speech.listen(
          onResult: (val) => onResult(val.recognizedWords),
          localeId: localeId,
          listenFor: const Duration(seconds: 60), // Allow up to 60s per session
          pauseFor: const Duration(seconds: 20), // Allow 20s of silence before auto-stop
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation
        );
      } catch (e) {
        debugPrint("Error starting listening: $e");
        _isListening = false;
        _listeningController.add(false);
      }
    }
  }

  Future<void> stopListening() async {
    if (_speech.isListening || _isListening) {
      _isListening = false;
      _listeningController.add(false); // Optimistic update
      await _speech.stop();
    }
  }
}
