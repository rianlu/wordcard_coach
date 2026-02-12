import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/utils/phonetic_utils.dart';
import '../../../../core/widgets/animated_speaker_button.dart';
import 'package:flutter_animate/flutter_animate.dart';


import 'practice_success_overlay.dart';

/// 口语练习状态
enum SpeakingState { 
  idle,          // 空闲
  playingAudio,  // 播放标准音
  listening,     // 录音识别中
  processing,    // 处理识别结果
  success,       // 识别通过
  failed         // 识别失败
}

class SpeakingPracticeView extends StatefulWidget {
  final Word word;
  final Function(int score) onCompleted;

  const SpeakingPracticeView({
    super.key, 
    required this.word, 
    required this.onCompleted,
  });

  @override
  State<SpeakingPracticeView> createState() => _SpeakingPracticeViewState();
}

class _SpeakingPracticeViewState extends State<SpeakingPracticeView> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  
  // 练习状态
  SpeakingState _state = SpeakingState.idle;
  String _lastHeard = ''; // 最近一次识别内容
  bool _hasPlayedAudioForCurrentWord = false; // 本轮是否已播放标准音
  int _sessionToken = 0; // 用于隔离旧异步回调
  bool _isStartingRecognition = false; // 防并发 startListening

  
  // 计时器
  Timer? _skipTimer;
  Timer? _listenTimeoutTimer;
  Timer? _successTimer;
  
  // 配置
  static const int _skipButtonDelaySeconds = 3;
  static const int _listenTimeoutSeconds = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // 启动练习流程
    _startPractice();
  }

  @override
  void didUpdateWidget(SpeakingPracticeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.word.id != oldWidget.word.id) {
      unawaited(_resetAndRestart());
    }
  }

  Future<void> _resetAndRestart() async {
    _sessionToken++;
    final token = _sessionToken;
    _cancelAllTimers();
    await SpeechService().cancel();
    if (!mounted || token != _sessionToken) return;
    
    setState(() {
      _state = SpeakingState.idle;
      _lastHeard = '';
      _hasPlayedAudioForCurrentWord = false;
      _isStartingRecognition = false;

    });
    
    _pulseController.reset();
    await _startPractice(token);
  }

  void _cancelAllTimers() {
    _skipTimer?.cancel();
    _listenTimeoutTimer?.cancel();
    _successTimer?.cancel();
  }

  @override
  void dispose() {
    _sessionToken++;
    _cancelAllTimers();
    _pulseController.dispose();
    SpeechService().cancel(); // Key 机制保证新实例在旧实例 dispose 后才创建
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _cancelAllTimers();
      SpeechService().stopListening();
      _pulseController.stop();
      setState(() {
        _state = SpeakingState.failed;
        _lastHeard = '';
      });
      _isStartingRecognition = false;
    }
  }

  /// 启动口语练习流程
  Future<void> _startPractice([int? token]) async {
    final currentToken = token ?? _sessionToken;
    if (!mounted || currentToken != _sessionToken) return;
    
    // 避免界面切换瞬间触发
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted || currentToken != _sessionToken) return;
    
    // 播放标准音的同时，后台预初始化语音引擎（避免第一次超时）
    setState(() => _state = SpeakingState.playingAudio);
    unawaited(SpeechService().ensureInitialized());
    
    await AudioService().playWord(widget.word);
    if (!mounted || currentToken != _sessionToken) return;
    _hasPlayedAudioForCurrentWord = true;
    
    // 播放完成后进入识别
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || currentToken != _sessionToken) return;
    
    // 开始监听
    unawaited(_beginListening(currentToken));
  }

  Future<void> _beginListening([int? token]) async {
    final currentToken = token ?? _sessionToken;
    if (!mounted || currentToken != _sessionToken || _state == SpeakingState.success) return;
    if (_isStartingRecognition) {
      debugPrint('Speaking: _beginListening skipped, recognition start in progress');
      return;
    }
    
    // 启动前清理旧计时器
    _skipTimer?.cancel();
    _listenTimeoutTimer?.cancel();
    
    setState(() {
      _state = SpeakingState.processing;
      _lastHeard = '';
    });
    _isStartingRecognition = false;

    bool success = false;
    try {
      success = await _startSpeechRecognition(currentToken).timeout(const Duration(seconds: 12));
    } catch (_) {
      success = false;
    }
    if (!mounted || currentToken != _sessionToken) return;
    if (!success) {
      _handleStartListeningFailed('识别引擎启动超时或失败');
      return;
    }

    setState(() {
      _state = SpeakingState.listening;
    });
    _pulseController.repeat();

    // 控制跳过按钮显示时机
    _skipTimer = Timer(const Duration(seconds: _skipButtonDelaySeconds), () {
      if (mounted) setState(() {});  // 刷新界面
    });

    // 监听超时保护
    _listenTimeoutTimer = Timer(const Duration(seconds: _listenTimeoutSeconds), () {
      _handleListenTimeout(currentToken);
    });
  }

  Future<bool> _startSpeechRecognition([int? token]) async {
    final currentToken = token ?? _sessionToken;
    if (!mounted || currentToken != _sessionToken) return false;
    if (_isStartingRecognition) return false;
    _isStartingRecognition = true;
    final success = await SpeechService().startListening(
      onResult: (text) {
        if (currentToken != _sessionToken) return; // 过滤旧 session 的结果
        _handleSpeechResult(text);
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (mounted && currentToken == _sessionToken && _state == SpeakingState.listening) {
          _handleStartListeningFailed(error);
        }
      },
    );
    _isStartingRecognition = false;
    return success;
  }

  void _handleStartListeningFailed(String reason) {
    debugPrint('Start listening failed: $reason');
    _cancelAllTimers();
    SpeechService().stopListening();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _state = SpeakingState.failed;
      _lastHeard = '';
    });
    _isStartingRecognition = false;
  }

  void _handleListenTimeout([int? token]) {
    final currentToken = token ?? _sessionToken;
    if (currentToken != _sessionToken) return;
    if (!mounted || _state != SpeakingState.listening) return;
    
    debugPrint('Listen timeout');
    _handleStartListeningFailed('监听超时');
  }

  void _handleSpeechResult(String text) {
    if (!mounted || _state != SpeakingState.listening) return;
    
    final recognized = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (recognized.isEmpty) return;
    
    setState(() => _lastHeard = recognized);
    
    final target = widget.word.text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    
    // 计算匹配质量与星级
    final stars = _calculateStars(recognized, target);
    
    // 2 星以上才自动通过
    if (stars >= 2) {
      _handleResult(stars, recognized);
    } else if (stars == 1) {
      // 部分匹配时提示重试
      debugPrint('Partial match only (1 star), prompting retry');
      _listenTimeoutTimer?.cancel(); // 已有输入，取消超时
      _showRetryPrompt(recognized);
    }
    // 0 星时继续监听更多输入
  }

  /// 根据匹配质量计算星级
  /// 规范教育场景常见缩写
  /// 将缩写映射为发音形式以提高匹配
  String _normalizeAbbreviations(String text) {
    final abbreviations = {
      'sb.': 'somebody',
      'sb': 'somebody',
      'sth.': 'something', 
      'sth': 'something',
      'esp.': 'especially',
      'etc.': 'et cetera',
      'e.g.': 'for example',
      'i.e.': 'that is',
      'vs.': 'versus',
      'adj.': 'adjective',
      'adv.': 'adverb',
      'n.': 'noun',
      'v.': 'verb',
      'prep.': 'preposition',
    };
    
    String result = text.toLowerCase();
    abbreviations.forEach((abbr, full) {
      result = result.replaceAll(abbr.toLowerCase(), full);
    });
    
    // 移除标点以便匹配
    result = result.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return result;
  }

  /// 根据识别匹配度计算星级
  int _calculateStars(String recognized, String target) {
    // 规范化字符串以便比较
    String normalizedRecognized = _normalizeAbbreviations(recognized);
    String normalizedTarget = _normalizeAbbreviations(target);
    
    // 检查完全匹配或包含关系
    if (normalizedRecognized == normalizedTarget || normalizedRecognized.contains(normalizedTarget)) {
      return 3; // 完全匹配
    }
    
    // 使用编辑距离判断近似
    int distance = _levenshtein(normalizedRecognized, normalizedTarget);
    
    if (distance <= 1) {
      return 3; // 非常接近，视为完美匹配
    }
    
    if (distance <= 3) {
      return 2; // 匹配良好
    }
    
    // 使用 音标算法 做语音相似匹配
    String targetSoundex = PhoneticUtils.soundex(normalizedTarget);
    for (String word in normalizedRecognized.split(' ')) {
      if (PhoneticUtils.soundex(word) == targetSoundex) {
        return 2; // 发音相似
      }
    }
    
    // 检查目标词是否出现在识别结果中
    List<String> targetWords = normalizedTarget.split(' ');
    List<String> recognizedWords = normalizedRecognized.split(' ');
    
    int matchedWords = 0;
    for (String tw in targetWords) {
      if (tw.length < 2) continue; // 跳过过短的词
      if (recognizedWords.any((rw) => rw == tw || _levenshtein(rw, tw) <= 1)) {
        matchedWords++;
      }
    }
    
    // 大部分匹配则判定为较好
    if (targetWords.isNotEmpty && matchedWords >= targetWords.length * 0.7) {
      return 2;
    }
    
    // 检查目标词是否以其他形式出现
    if (recognizedWords.any((w) => _levenshtein(w, normalizedTarget) <= 2)) {
      return 1; // 部分匹配时提示重试
    }
    
    // 检测到语音但未匹配时返回 1
    if (recognized.isNotEmpty) {
      return 1;
    }
    
    return 0; // 完全未匹配
  }

  /// 检测到语音但匹配差时进入失败态，等待用户手动重新开始
  void _showRetryPrompt(String recognized) {
    if (!mounted) return;
    
    // 播放错误音效
    AudioService().playAsset('wrong.mp3');
    
    // 取消计时并停止当前监听
    _skipTimer?.cancel();
    _listenTimeoutTimer?.cancel();
    SpeechService().stopListening();
    _pulseController.stop();
    
    setState(() {
      _state = SpeakingState.failed;
    });
    _isStartingRecognition = false;
  }

  void _handleResult(int stars, String recognized) {
    if (!mounted || _state == SpeakingState.success) return;
    
    _cancelAllTimers();
    SpeechService().stopListening();
    _pulseController.stop();
    _pulseController.reset();
    
    setState(() {
      _state = SpeakingState.success;

      _lastHeard = recognized;
    });
    _isStartingRecognition = false;
    
    _showSuccessOverlay(stars);
  }



  Future<void> _skip() async {
    _sessionToken++;
    _cancelAllTimers();
    await SpeechService().cancel();
    if (!mounted) return;
    _pulseController.stop();
    _pulseController.reset();
    _isStartingRecognition = false;
    widget.onCompleted(0); // 跳过记 0 分
  }

  void _replayStandardAudio() async {
    final currentToken = _sessionToken;
    // 成功或正在播放时不允许重播
    if (_state == SpeakingState.success || _state == SpeakingState.playingAudio || _state == SpeakingState.processing) return;
    
    final wasListening = _state == SpeakingState.listening;
    
    if (wasListening) {
      // 监听中：暂停监听，播放音频，再恢复监听
      await SpeechService().stopListening();
      _listenTimeoutTimer?.cancel();
      _pulseController.stop();
    }
    
    setState(() => _state = SpeakingState.playingAudio);
    
    await AudioService().playWord(widget.word);
    if (!mounted || currentToken != _sessionToken) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || currentToken != _sessionToken) return;
    
    if (wasListening) {
      // 之前在监听，恢复监听
      unawaited(_beginListening(currentToken));
    } else {
      // 之前在 idle/failed，播放完回到原状态，用户可以点麦克风开始
      setState(() => _state = SpeakingState.failed);
    }
  }

  void _showSuccessOverlay(int stars) {
    // 音效
    AudioService().playAsset('correct.mp3');
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (context, a1, a2) {
        return PracticeSuccessOverlay(
          word: widget.word,
          title: _getStarTitle(stars),
          stars: stars,
        );
      },
    );

    // 播放单词读音 稍作延迟后
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        AudioService().playWord(widget.word);
      }
    });

    // 自动进入下一题
    _successTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭提示层
        widget.onCompleted(stars);
      }
    });
  }

  String _getStarTitle(int stars) {
    switch (stars) {
      case 3: return '太棒了！';
      case 2: return '不错哦！';
      case 1: return '继续加油！';
      default: return '完成！';
    }
  }

  // 编辑距离算法
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((min, e) => e < min ? e : min);
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  /// 判断是否显示跳过按钮
  bool _shouldShowSkipButton() {
    // 监听超时后显示跳过
    if (_state == SpeakingState.listening && _skipTimer?.isActive == false) {
      return true;
    }
    // 失败态始终允许跳过
    if (_state == SpeakingState.failed) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > constraints.maxHeight && constraints.maxWidth > 480;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTargetWord(),
                        const SizedBox(height: 32),
                        _buildStatusHUD(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white54,
                      border: Border(left: BorderSide(color: Colors.black12)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        _buildVoiceWave(),
                        const Spacer(),
                        _buildVoiceControls(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // 竖屏布局
          return Column(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      _buildTargetWord(),
                      const SizedBox(height: 32),
                      _buildStatusHUD(),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              
              // 底部控制区
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVoiceWave(),
                    const SizedBox(height: 32),
                    _buildVoiceControls(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceWave() {
     // 音频可视化占位
     return SizedBox(
       height: 60,
       child: Center(
         child: _state == SpeakingState.listening 
           ? Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: List.generate(5, (index) => 
                 Container(
                   width: 6,
                   height: 20 + 20 * (index % 2 == 0 ? 1.0 : 0.6), // 模拟波形
                   margin: const EdgeInsets.symmetric(horizontal: 4),
                   decoration: BoxDecoration(
                     color: AppColors.primary.withValues(alpha: 0.6),
                     borderRadius: BorderRadius.circular(10)
                   ),
                 ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleY(begin: 0.5, end: 1.5, duration: Duration(milliseconds: 300 + index * 100))
               ),
             )
           : const SizedBox.shrink()
       ),
     );
  }

  Widget _buildVoiceControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：跳过按钮/占位
          SizedBox(
            width: 80,
            child: _shouldShowSkipButton() 
              ? TextButton(
                  onPressed: _skip,
                  child: Text("跳过", style: TextStyle(color: Colors.grey.shade400)),
                )
              : const SizedBox(),
          ),

          // 中间：麦克风按钮
          _buildVoiceMicButton(),

          // 右侧：重播按钮
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedSpeakerButton(
                onPressed: _replayStandardAudio,
                isPlaying: _state == SpeakingState.playingAudio,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMicButton() {
    final isListening = _state == SpeakingState.listening;
    final isProcessing = _state == SpeakingState.processing;
    
    return GestureDetector(
      onTap: () {
        if (isProcessing) return; // 正在启动识别，忽略点击
        if (_state == SpeakingState.idle || _state == SpeakingState.failed) {
          _lastHeard = '';
          if (_hasPlayedAudioForCurrentWord) {
            unawaited(_beginListening(_sessionToken));
          } else {
            unawaited(_startPractice(_sessionToken));
          }
        } else if (_state == SpeakingState.listening) {
          _handleStartListeningFailed('用户手动取消');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening ? const Color(0xFFFF5252) 
               : isProcessing ? AppColors.primary.withValues(alpha: 0.7)
               : AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: (isListening ? const Color(0xFFFF5252) : AppColors.primary).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ]
        ),
        child: isProcessing
          ? const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : Icon(
              isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 32,
            ),
      ),
    );
  }

  Widget _buildTargetWord() {
    return Column(
      children: [
        Text(
          "READ ALOUD",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w900, 
            color: AppColors.textMediumEmphasis, letterSpacing: 1.0
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.word.text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 48, // 更大尺寸
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.word.phonetic,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textMediumEmphasis,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.word.meaning,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textHighEmphasis.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHUD() {
    String text;
    Color color;
    IconData? icon;

    switch (_state) {
      case SpeakingState.idle:
      case SpeakingState.playingAudio:
        text = '请听发音...';
        color = AppColors.textMediumEmphasis;
        icon = Icons.volume_up_rounded;
        break;
      case SpeakingState.listening:
        if (_lastHeard.isNotEmpty) {
          text = '听到: "$_lastHeard"';
          color = AppColors.primary;
          icon = Icons.hearing_rounded;
        } else {
          text = '请大声读出来...';
          color = AppColors.secondary;
          icon = Icons.mic_rounded;
        }
        break;
      case SpeakingState.processing:
        text = '准备识别...';
        color = AppColors.primary;
        icon = Icons.sync_rounded;
        break;
      case SpeakingState.success:
        text = '完美!';
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case SpeakingState.failed:
        text = '再试一次!';
        color = Colors.orange;
        icon = Icons.refresh_rounded;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_state),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }


}
