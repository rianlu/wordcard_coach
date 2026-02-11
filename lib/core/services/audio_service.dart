import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wordcard_coach/core/database/models/word.dart';

enum AudioType {
  us, // 逻辑处理
  uk, // 逻辑处理
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer(); // 音频控制
  final FlutterTts _flutterTts = FlutterTts();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  
  // 逻辑处理
  final AudioPlayer _sfxCorrect = AudioPlayer();
  final AudioPlayer _sfxWrong = AudioPlayer();
  final AudioPlayer _sfxMic = AudioPlayer();

  bool _isInit = false;

  // 逻辑处理
  Future<void> init() async {
    if (_isInit) return;
    
    // 逻辑处理
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    
    // 逻辑处理
    // 逻辑处理
    try {
        await _sfxCorrect.setSource(AssetSource('sounds/correct.mp3'));
        await _sfxCorrect.setReleaseMode(ReleaseMode.stop); // 逻辑处理
        
        await _sfxWrong.setSource(AssetSource('sounds/wrong.mp3'));
        await _sfxWrong.setReleaseMode(ReleaseMode.stop);

        await _sfxMic.setSource(AssetSource('sounds/mic_start.mp3'));
        await _sfxMic.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
        debugPrint("SFX Preload Error: $e");
    }

    _isInit = true;
  }

  /// 逻辑处理
  Future<void> playWord(Word word, {AudioType type = AudioType.us}) async {
    try {
      if (!_isInit) await init(); 

      // 逻辑处理
      _audioPlayer.stop();
      _flutterTts.stop();

      // 逻辑处理




      // 逻辑处理
      if (_isEnglish(word.text)) {
        final int apiType = type == AudioType.us ? 0 : 1;
        final String url = "http://dict.youdao.com/dictvoice?type=$apiType&audio=${Uri.encodeComponent(word.text)}";
        
        try {
          // 逻辑处理
          final FileInfo? cachedFile = await _cacheManager.getFileFromCache(url);
          if (cachedFile != null && await cachedFile.file.exists()) {
             // 逻辑处理
             await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
          }

          // 逻辑处理
          // 逻辑处理
          File file = await _cacheManager.getSingleFile(url);
          if (await file.exists()) {
             // 逻辑处理
             await _audioPlayer.play(DeviceFileSource(file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
          }

        } catch (e) {
          print("Youdao API failed for ${word.text}, falling back to Google. Error: $e");
          // 逻辑处理
        }
      }

      // 逻辑处理
      // 逻辑处理
      // 逻辑处理
      bool isSingleWord = !word.text.trim().contains(' ');
      
      if (isSingleWord && _isEnglish(word.text)) {
        try {
           final String cleanWord = word.text.trim().toLowerCase();
           final String googleUrl = "https://ssl.gstatic.com/dictionary/static/sounds/oxford/${cleanWord}--_us_1.mp3";
           
           // 逻辑处理
           final FileInfo? cachedFile = await _cacheManager.getFileFromCache(googleUrl);
           if (cachedFile != null && await cachedFile.file.exists()) {
             // 逻辑处理
             await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
           }

           // 逻辑处理
           // 逻辑处理
           File file = await _cacheManager.getSingleFile(googleUrl);
           if (await file.exists()) {
             // 逻辑处理
             await _audioPlayer.play(DeviceFileSource(file.path));
             try {
                await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 10));
             } catch (_) {}
             return;
           }


        } catch (e) {
          print("Google API failed for ${word.text}, falling back to TTS. Error: $e");
          // 逻辑处理
        }
      }
      
      // 逻辑处理
      print("Falling back to TTS for: ${word.text}");
       // 逻辑处理
      if (!_isInit) await init(); // 逻辑处理
      await _flutterTts.speak(word.text);
      await _flutterTts.awaitSpeakCompletion(true);
      
    } catch (e) {
      print("Audio playback init failed: $e");
    }
  }

  /// 逻辑处理
  Future<void> playSentence(String sentence) async {
      try {
        // 逻辑处理
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

        // 逻辑处理
        if (!_isInit) await init();
        await _flutterTts.speak(sentence);

      } catch (e) {
        print("Sentence playback failed: $e");
      }
  }

  Future<void> playAsset(String fileName) async {
    try {
       // 逻辑处理
       if (fileName.contains('correct')) {
           if (_sfxCorrect.state == PlayerState.playing) await _sfxCorrect.stop();
           await _sfxCorrect.resume(); // 逻辑处理
       } else if (fileName.contains('wrong')) {
           if (_sfxWrong.state == PlayerState.playing) await _sfxWrong.stop();
           await _sfxWrong.resume();
       } else if (fileName.contains('mic')) {
           if (_sfxMic.state == PlayerState.playing) await _sfxMic.stop();
           await _sfxMic.resume();
       } else {
           // 逻辑处理
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

  /// 逻辑处理
  /// 逻辑处理
  Future<void> playUrl(String url, {String? fallbackText}) async {
    // 逻辑处理
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

      // 逻辑处理
      Future<void> wait() async {
        try {
          await _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 20));
        } catch (e) {
          debugPrint("AudioService: Playback finished or timed out: $e");
        }
      }

      try {
        // 逻辑处理
        final FileInfo? cachedFile = await _cacheManager.getFileFromCache(url);
        if (cachedFile != null && await cachedFile.file.exists()) {
          debugPrint("AudioService: Playing from cache: ${cachedFile.file.path}");
          await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
          await wait();
          playedSuccessfully = true;
        } else {
          // 逻辑处理
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
          // 逻辑处理
          await _audioPlayer.play(UrlSource(url));
          await wait();
          playedSuccessfully = true;
        } catch (e2) {
          debugPrint("AudioService: Direct URL source also failed: $e2");
        }
      }

      // 逻辑处理
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
    return RegExp(r"^[a-zA-Z\s\.,\?!'-]+$").hasMatch(text);
  }
}
