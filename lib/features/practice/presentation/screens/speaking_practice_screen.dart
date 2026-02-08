import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:ui';

class SpeakingPracticeScreen extends StatefulWidget {
  const SpeakingPracticeScreen({super.key});

  @override
  State<SpeakingPracticeScreen> createState() => _SpeakingPracticeScreenState();
}



class _SpeakingPracticeScreenState extends State<SpeakingPracticeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isListening = false;
  
  // Data
  final WordDao _wordDao = WordDao();
  final UserStatsDao _userStatsDao = UserStatsDao();
  Word? _currentWord;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loadNewWord();
  }

  Future<void> _loadNewWord() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final stats = await _userStatsDao.getUserStats();
      final words = await _wordDao.getNewWords(
        1,
        grade: stats.currentGrade,
        semester: stats.currentSemester
      );
      if (words.isNotEmpty) {
        setState(() {
          _currentWord = words.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading word: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _controller.repeat();
        // Simulate successful speaking after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
           if (mounted && _isListening) {
             _toggleListening();
             // Load next word
             _loadNewWord();
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Great job! Correct pronunciation.'), backgroundColor: Colors.green)
             );
           }
        });
      } else {
        _controller.stop();
        _controller.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(
         backgroundColor: AppColors.background,
         body: Center(child: CircularProgressIndicator()),
       );
    }

    if (_currentWord == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
           leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('No words available')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_currentWord!.unit, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars_rounded, color: AppColors.secondary, size: 20),
                SizedBox(width: 4),
                Text('120 XP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Enhanced wide detection: >600 (Tablet) OR (>480 && Landscape)
          final isWide = constraints.maxWidth > 600 || (constraints.maxWidth > constraints.maxHeight && constraints.maxWidth > 480);

          if (isWide) {
            // LANDSCAPE / WIDE LAYOUT
            return Row(
              children: [
                // Left Panel: Content
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildWordCard(),
                        const SizedBox(height: 16),
                        _buildExampleCard(),
                      ],
                    ),
                  ),
                ),
                // Right Panel: Interaction
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.black12)),
                      color: Colors.white54,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        _buildMicSection(),
                        const Spacer(),
                        _buildProgressSection(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          
          // PORTRAIT / NARROW LAYOUT
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildWordCard(),
                      const SizedBox(height: 16),
                      _buildExampleCard(),
                      const SizedBox(height: 48),
                      _buildMicSection(),
                    ],
                  ),
                ),
              ),
              _buildProgressSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 0)
        ]
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(_currentWord!.text, style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(_currentWord!.meaning, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
          const SizedBox(height: 8),
          Text(_currentWord!.phonetic, style: const TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          
          // TTS Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            ),
            child: IconButton(
              padding: const EdgeInsets.all(14),
              onPressed: () {},
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.shadowWhite, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
         boxShadow: const [
            BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 2), blurRadius: 0)
         ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EXAMPLE SENTENCE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
           const SizedBox(height: 8),
           Text(
             'No example sentence available for "${_currentWord!.text}".',
             style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textHighEmphasis, height: 1.5, fontWeight: FontWeight.w500),
           ),
           const SizedBox(height: 8),
           Text(
             '暂无例句',
             style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textMediumEmphasis, height: 1.5),
           ),
        ],
      ),
    );
  }

  Widget _buildMicSection() {
    return Column(
      children: [
        Text(
            _isListening ? 'Listening...' : 'TAP TO SPEAK',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _isListening ? AppColors.secondary : AppColors.textMediumEmphasis,
                letterSpacing: 1.0
            )
        ),
        const SizedBox(height: 24),
        // Mic Interaction
        GestureDetector(
          // 长按开始
          onTapDown: (_) => _toggleListening(),
          // 松开结束
          onTapUp: (_) => _toggleListening(),
          onTapCancel: () => _isListening ? _toggleListening() : null,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple Effect
                if (_isListening)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        width: 90 + (_controller.value * 70),
                        height: 90 + (_controller.value * 70),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // 随着动画进度，透明度从 0.6 变为 0.0，产生消失感
                          color: AppColors.secondary.withOpacity(0.6 * (1 - _controller.value)),
                          // 增加边框会让波纹更有边界感
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.3 * (1 - _controller.value)),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                // Main Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  // 按住时稍微放大一点 (90 -> 100)，增加交互反馈
                  width: _isListening ? 100 : 90,
                  height: _isListening ? 100 : 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.4),
                        blurRadius: _isListening ? 30 : 20,
                        spreadRadius: _isListening ? 4 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                      _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      color: const Color(0xFF101418),
                      size: 42
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: const BoxDecoration(
         color: Colors.white,
         boxShadow: [BoxShadow(color: Colors.black12, offset: Offset(0, -4), blurRadius: 16)]
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0.66, 
              color: AppColors.primary,
              backgroundColor: Color(0xFFe2e8f0),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PROGRESS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
              Text('8 / 12 WORDS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
            ],
          )
        ],
      ),
    );
  }
}
