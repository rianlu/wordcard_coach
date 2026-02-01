import 'package:flutter/material.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';

class WordSelectionScreen extends StatefulWidget {
  const WordSelectionScreen({super.key});

  @override
  State<WordSelectionScreen> createState() => _WordSelectionScreenState();
}

class _WordSelectionScreenState extends State<WordSelectionScreen> {
  final WordDao _wordDao = WordDao();
  Word? _currentWord;
  List<Word> _options = [];
  bool _isLoading = true;
  String? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    _loadNewWord();
  }

  Future<void> _loadNewWord() async {
    setState(() {
      _isLoading = true;
      _selectedOptionId = null;
    });

    try {
      // Get 4 words: 1 correct + 3 distractors
      final words = await _wordDao.getNewWords(4);
      if (words.isNotEmpty) {
        _currentWord = words[0];
        _options = List.from(words)..shuffle();
      }
    } catch (e) {
      debugPrint('Error loading words: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleOptionSelected(String wordId) {
    if (_selectedOptionId != null) return; // Already selected

    setState(() {
      _selectedOptionId = wordId;
    });

    // Simple delay to show result then load next word
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _loadNewWord();
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
        appBar: AppBar(),
        body: const Center(child: Text('No words available for practice!')),
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
                Icon(Icons.stars, color: AppColors.secondary, size: 20),
                SizedBox(width: 4),
                Text('120 XP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Word Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowWhite, offset: Offset(0,4), blurRadius: 0),
                  BoxShadow(color: Colors.black12, offset: Offset(0, 4), blurRadius: 20, spreadRadius: -2)
                ]
              ),
              child: Column(
                children: [
                   // Image Placeholder
                   Container(
                     height: 180,
                     decoration: BoxDecoration(
                       color: Colors.grey.shade100,
                       borderRadius: BorderRadius.circular(16),
                       // Placeholder image, or could try to fetch one based on word text if API available
                       image: const DecorationImage(
                          image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCDBymxy7qPY9zCgzSGficR5l_06WvrlthK4z9Laa1YC04TT1UIUlEPmXeaLCdfI4VreuS4qruobJQ9lFDxeBd4oL_cPyfbtZ26e8hfsWFijDqNxfyCBFGd6UPvDmUfnlYPKc6tlmKYghR1O7KUD1QybdNYKxjz_GGJf_WuVPYvN9zALLTAoMZ-1XOdle_NruLKUZNme-WtQNdFbhFS92VwpaeGDkJZJZcpQR0uQdU3RyN4KVznFgRQmR8PUpHlpIXcuLi6zEVzzfM'), // Keep existing placeholder for now
                          fit: BoxFit.cover,
                       ),
                     ),
                     alignment: Alignment.bottomRight,
                     child: Padding(
                       padding: const EdgeInsets.all(12),
                       child: CircleAvatar(
                         backgroundColor: Colors.white,
                         child: IconButton(
                           icon: const Icon(Icons.volume_up, color: AppColors.primary),
                           onPressed: () {
                             // TTS placeholder
                           },
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(height: 24),
                   Text(_currentWord!.text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
                   Text(_currentWord!.phonetic, style: const TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft, 
              child: Text('SELECT THE CORRECT MEANING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMediumEmphasis, letterSpacing: 1.0))
            ),
             const SizedBox(height: 16),
             
             ..._options.map((optionWord) => 
               Padding(
                 padding: const EdgeInsets.only(bottom: 12),
                 child: _buildOption(context, optionWord),
               )
             ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, Word optionWord) {
    // Check if this option is selected
    final isSelected = _selectedOptionId == optionWord.id;
    // Check if this option is correct (only if an option has been selected)
    final isCorrect = optionWord.id == _currentWord!.id;
    
    // Determine color state
    Color? buttonColor = Colors.white;
    Color? textColor = AppColors.textHighEmphasis;
    Widget? icon;

    if (_selectedOptionId != null) {
      if (isCorrect) {
        buttonColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = const Icon(Icons.check, size: 20, color: Colors.green);
      } else if (isSelected) {
        buttonColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        icon = const Icon(Icons.close, size: 20, color: Colors.red);
      }
    }

    // Display meaning if available, otherwise word text (since meaning is placeholder)
    // Actually our placeholder is '[释义]', maybe append word text to distinguish?
    // Let's just show text for now since meaning is not real.
    // User requested "connect pages...". I'll show "meaning (text)" or just "text" if meaning is broken.
    final displayText = "${optionWord.meaning} (${optionWord.text})";

    return BubblyButton(
      onPressed: () => _handleOptionSelected(optionWord.id),
      color: buttonColor,
      shadowColor: Colors.grey.shade200,
      shadowHeight: 4,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(displayText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
           Container(
             width: 24, height: 24,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(color: Colors.grey.shade300, width: 2),
             ),
             child: icon,
           )
        ],
      )
    );
  }
}
