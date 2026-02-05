import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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

  final AudioPlayer _audioPlayer = AudioPlayer(); // Main player for words
  final FlutterTts _flutterTts = FlutterTts();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  
  // Dedicated low-latency players for SFX
  final AudioPlayer _sfxCorrect = AudioPlayer();
  final AudioPlayer _sfxWrong = AudioPlayer();
  final AudioPlayer _sfxMic = AudioPlayer();

  bool _isInit = false;

  // Initialize Service
  Future<void> init() async {
    if (_isInit) return;
    
    // 1. Init TTS
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    
    // 2. Preload SFX inputs to reduce latency
    // setSource prepares the file so play() is instant
    try {
        await _sfxCorrect.setSource(AssetSource('sounds/correct.mp3'));
        await _sfxCorrect.setReleaseMode(ReleaseMode.stop); // Ready to query again
        
        await _sfxWrong.setSource(AssetSource('sounds/wrong.mp3'));
        await _sfxWrong.setReleaseMode(ReleaseMode.stop);

        await _sfxMic.setSource(AssetSource('sounds/mic_start.mp3'));
        await _sfxMic.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
        debugPrint("SFX Preload Error: $e");
    }

    _isInit = true;
  }

  /// Play audio for a word using Youdao API, fallback to TTS
  Future<void> playWord(Word word, {AudioType type = AudioType.us}) async {
    try {
      if (!_isInit) await init(); 

      // Fire and forget stop command
      _audioPlayer.stop();
      _flutterTts.stop();

      // ... (Rest of playWord implementation logic remains same, just ensuring init is called)




      // 1. Try Youdao API (Primary - Fast in China)
      if (_isEnglish(word.text)) {
        final int apiType = type == AudioType.us ? 0 : 1;
        final String url = "http://dict.youdao.com/dictvoice?type=$apiType&audio=${Uri.encodeComponent(word.text)}";
        
        try {
          // Check Cache First
          final FileInfo? cachedFile = await _cacheManager.getFileFromCache(url);
          if (cachedFile != null && await cachedFile.file.exists()) {
             // print("Audio Cache Hit (Youdao): ${word.text}");
             await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
          }

          // Download if not in cache
          // print("Audio Downloading (Youdao): ${word.text}");
          File file = await _cacheManager.getSingleFile(url);
          if (await file.exists()) {
             // print("Played Downloaded (Youdao): ${word.text}");
             await _audioPlayer.play(DeviceFileSource(file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
          }

        } catch (e) {
          print("Youdao API failed for ${word.text}, falling back to Google. Error: $e");
          // Fallthrough to Google
        }
      }

      // 2. Try Google Dictionary API (Secondary - Good quality but unstable in China)
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
             // print("Audio Cache Hit (Google): $cleanWord");
             await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
           }

           // Download if not in cache
           // print("Audio Downloading (Google): $cleanWord");
           File file = await _cacheManager.getSingleFile(googleUrl);
           if (await file.exists()) {
             // print("Played Downloaded (Google): $cleanWord");
             await _audioPlayer.play(DeviceFileSource(file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
           }


        } catch (e) {
          print("Google API failed for ${word.text}, falling back to TTS. Error: $e");
          // Fallthrough to TTS
        }
      }
      
      // 3. Fallback to TTS (or if not English)
      print("Falling back to TTS for: ${word.text}");
       // Temporarily adjust speed for Chinese if needed, but for now keep default
      if (!_isInit) await init(); // Init TTS only when needed
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
        if (!_isInit) await init();
        await _flutterTts.speak(sentence);

      } catch (e) {
        print("Sentence playback failed: $e");
      }
  }

  Future<void> playAsset(String fileName) async {
    try {
       // Route to dedicated pre-warmed players for zero latency
       if (fileName.contains('correct')) {
           if (_sfxCorrect.state == PlayerState.playing) await _sfxCorrect.stop();
           await _sfxCorrect.resume(); // resume() starts from beginning if source is set
       } else if (fileName.contains('wrong')) {
           if (_sfxWrong.state == PlayerState.playing) await _sfxWrong.stop();
           await _sfxWrong.resume();
       } else if (fileName.contains('mic')) {
           if (_sfxMic.state == PlayerState.playing) await _sfxMic.stop();
           await _sfxMic.resume();
       } else {
           // Fallback for other assets
           final tempPlayer = AudioPlayer();
           await tempPlayer.play(AssetSource('sounds/$fileName'));
           tempPlayer.onPlayerComplete.listen((_) => tempPlayer.dispose());
       }
    } catch (e) {
      debugPrint("Asset playback failed ($fileName): $e");
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    await _sfxCorrect.stop();
    await _sfxWrong.stop();
    await _sfxMic.stop();
  }

  /// Play audio from a URL directly (e.g., for daily sentence)
  /// If playback fails, uses [fallbackText] with TTS as a backup.
  Future<void> playUrl(String url, {String? fallbackText}) async {
    // 1. If URL is missing, try fallback text immediately
    if (url.isEmpty || !url.startsWith('http')) {
      debugPrint("AudioService: No valid URL found ($url), using TTS fallback...");
      if (fallbackText != null && fallbackText.isNotEmpty) {
        if (!_isInit) await init();
        await stop();
        await _flutterTts.speak(fallbackText);
        await _flutterTts.awaitSpeakCompletion(true);
      }
      return;
    }

    try {
      debugPrint("AudioService: Attempting to play URL: $url");
      if (!_isInit) await init();
      await stop(); 
      
      bool playedSuccessfully = false;

      // Helper to wait for playback (either finishes or times out)
      Future<void> wait() async {
        try {
          await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 20));
        } catch (e) {
          debugPrint("AudioService: Playback finished or timed out: $e");
        }
      }

      try {
        // Step A: Try playing via Cache
        final FileInfo? cachedFile = await _cacheManager.getFileFromCache(url);
        if (cachedFile != null && await cachedFile.file.exists()) {
          debugPrint("AudioService: Playing from cache: ${cachedFile.file.path}");
          await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
          await wait();
          playedSuccessfully = true;
        } else {
          // Step B: Download to Cache and Play
          debugPrint("AudioService: Downloading to cache...");
          File file = await _cacheManager.getSingleFile(url);
          if (await file.exists()) {
            debugPrint("AudioService: Downloaded, playing: ${file.path}");
            await _audioPlayer.play(DeviceFileSource(file.path));
            await wait();
            playedSuccessfully = true;
          }
        }
      } catch (e) {
        debugPrint("AudioService: Cache/Direct file playback failed: $e. Trying direct URL source...");
        try {
          // Step C: Last resort - Stream directly from URL
          await _audioPlayer.play(UrlSource(url));
          await wait();
          playedSuccessfully = true;
        } catch (e2) {
          debugPrint("AudioService: Direct URL source also failed: $e2");
        }
      }

      // Step D: Ultimate Fallback to System TTS only if URL fails
      if (!playedSuccessfully && fallbackText != null && fallbackText.isNotEmpty) {
        debugPrint("AudioService: All URL sources failed. Falling back to system TTS for: $fallbackText");
        _flutterTts.stop();
        await _flutterTts.speak(fallbackText);
        await _flutterTts.awaitSpeakCompletion(true);
      }
      
    } catch (e) {
      debugPrint("AudioService: playUrl Critical Error: $e");
    }
  }
  
  bool _isEnglish(String text) {
    return RegExp(r'^[a-zA-Z\s\.,\?!]+$').hasMatch(text);
  }
}
