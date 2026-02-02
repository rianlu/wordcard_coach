import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wordcard_coach/core/database/models/word.dart';

enum AudioType {
  us, // American English (type=0)
  uk, // British English (type=1)
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  bool _isTtsInit = false;

  // Initialize TTS as fallback
  Future<void> init() async {
    if (_isTtsInit) return;
    // await _flutterTts.awaitSpeakCompletion(true); // Disable this for now if it causes delay, or keep it if needed for sync. 
    // Actually, we only use awaitSpeakCompletion for TTS. For AudioPlayer we manage it manually.
    await _flutterTts.awaitSpeakCompletion(true);

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _isTtsInit = true;
  }

  /// Play audio for a word using Youdao API, fallback to TTS
  Future<void> playWord(Word word, {AudioType type = AudioType.us}) async {
    try {
      // if (!_isTtsInit) await init(); // Optimization: Don't block MP3 playback for TTS init

      
      // Fire and forget stop command to avoid platform channel latency
      _audioPlayer.stop();
      _flutterTts.stop();




      // 1. Try Google Dictionary API (Primary for Single Words)
      // URL Format: https://ssl.gstatic.com/dictionary/static/sounds/oxford/{word}--_us_1.mp3
      // Constraint: Single words only (no spaces)
      bool isSingleWord = !word.text.trim().contains(' ');
      
      if (isSingleWord && _isEnglish(word.text)) {
        try {
           final String cleanWord = word.text.trim().toLowerCase();
           final String googleUrl = "https://ssl.gstatic.com/dictionary/static/sounds/oxford/${cleanWord}--_us_1.mp3";
           
           // Check Cache First
           final FileInfo? cachedFile = await _cacheManager.getFileFromCache(googleUrl);
           if (cachedFile != null && await cachedFile.file.exists()) {
             print("Audio Cache Hit (Google): $cleanWord");
             await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
           }

           // Download if not in cache
           print("Audio Downloading (Google): $cleanWord");
           File file = await _cacheManager.getSingleFile(googleUrl);
           if (await file.exists()) {
             print("Played Downloaded (Google): $cleanWord");
             await _audioPlayer.play(DeviceFileSource(file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
           }


        } catch (e) {
          print("Google API failed for ${word.text}, falling back to Youdao. Error: $e");
          // Fallthrough to Youdao
        }
      }

      // 2. Try Youdao API (Secondary / For Phrases)
      if (_isEnglish(word.text)) {
        final int apiType = type == AudioType.us ? 0 : 1;
        final String url = "http://dict.youdao.com/dictvoice?type=$apiType&audio=${Uri.encodeComponent(word.text)}";
        
        try {
          // Check Cache First
          final FileInfo? cachedFile = await _cacheManager.getFileFromCache(url);
          if (cachedFile != null && await cachedFile.file.exists()) {
             print("Audio Cache Hit (Youdao): ${word.text}");
             await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
          }

          // Download if not in cache
          print("Audio Downloading (Youdao): ${word.text}");
          File file = await _cacheManager.getSingleFile(url);
          if (await file.exists()) {
             print("Played Downloaded (Youdao): ${word.text}");
             await _audioPlayer.play(DeviceFileSource(file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
          }

        } catch (e) {
          print("Youdao API failed for ${word.text}, falling back to TTS. Error: $e");
          // Fallthrough to TTS
        }
      }
      
      // 3. Fallback to TTS (or if not English)
      print("Falling back to TTS for: ${word.text}");
       // Temporarily adjust speed for Chinese if needed, but for now keep default
      if (!_isTtsInit) await init(); // Init TTS only when needed
      await _flutterTts.speak(word.text);
      await _flutterTts.awaitSpeakCompletion(true);
      
    } catch (e) {
      print("Audio playback init failed: $e");
    }
  }

  /// Play sentence audio (Youdao supports some, otherwise TTS)
  Future<void> playSentence(String sentence) async {
      try {
        // if (!_isTtsInit) await init(); // Optimization
        await stop();

        if (_isEnglish(sentence)) {
             final String url = "http://dict.youdao.com/dictvoice?type=0&audio=${Uri.encodeComponent(sentence)}";
              try {
                File file = await _cacheManager.getSingleFile(url);
                if (await file.exists()) {
                   await _audioPlayer.play(DeviceFileSource(file.path));
                   await _audioPlayer.onPlayerComplete.first;
                   return;
                }
              } catch (e) {
                print("Sentence Cache error: $e");
              }
        }

        // Fallback
        if (!_isTtsInit) await init();
        await _flutterTts.speak(sentence);

      } catch (e) {
        print("Sentence playback failed: $e");
      }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
  }
  
  bool _isEnglish(String text) {
    return RegExp(r'^[a-zA-Z\s\.,\?!]+$').hasMatch(text);
  }
}
