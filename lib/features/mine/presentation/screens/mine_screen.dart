import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math' as dart;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wordcard_coach/features/mine/presentation/screens/settings_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/models/user_stats.dart';
import '../../../../core/services/global_stats_notifier.dart';
import '../../../../core/database/database_helper.dart';

class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  final UserStatsDao _userStatsDao = UserStatsDao();
  final StatsDao _statsDao = StatsDao();
  final WordDao _wordDao = WordDao(); // Add WordDao
  UserStats? _stats;
  BookProgress? _bookProgress;
  bool _isLoading = true;
  List<dynamic> _booksManifest = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    GlobalStatsNotifier.instance.addListener(_loadStats);
  }

  Future<void> _generateMockData() async {
    setState(() => _isLoading = true);
    
    final r =  dart.Random();
    final now = DateTime.now();

    // Generate data for past 14 days
    for (int i = 1; i <= 14; i++) {
       final date = now.subtract(Duration(days: i));
       
       // Randomize activity
       if (r.nextDouble() > 0.2) { // 80% active
          int newWords = r.nextInt(15);
          int reviewWords = r.nextInt(30) + 10;
          int correct = (reviewWords * (0.6 + r.nextDouble() * 0.4)).round(); // 60-100% accuracy
          int wrong = reviewWords - correct;
          int minutes = r.nextInt(30) + 10;
          
          await _statsDao.recordDailyActivity(
            newWords: newWords, 
            reviewWords: reviewWords, 
            correct: correct, 
            wrong: wrong, 
            minutes: minutes,
            date: date
          );
       }
    }

    // 2. Generate "Due" words for today's review
    // Fetch 20 new words (words without progress)
    final newWords = await _wordDao.getNewWords(20, grade: _stats?.currentGrade, semester: _stats?.currentSemester);
    if (newWords.isNotEmpty) {
       // Access DB directly via helper instance used by DAOs
       final db = await DatabaseHelper().database;
       
       final batch = db.batch();
       final yesterday = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
       
       for (var word in newWords) {
          batch.insert('word_progress', {
            'id': 'progress_${word.id}',
            'word_id': word.id,
            'created_at': yesterday,
            'updated_at': yesterday,
            'easiness_factor': 2.5,
            'interval': 1,
            'repetition': 1,
            'next_review_date': yesterday, // Due immediately
            'last_review_date': yesterday,
            'review_count': 1,
            'mastery_level': 1,
            'correct_count': 1,
            'wrong_count': 0,
            'speak_mode_count': 0,
            'spell_mode_count': 0,
            'select_mode_count': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
       }
       await batch.commit(noResult: true);
    }
    
    // Also record today if empty? No, let's just refresh.
    await _loadStats();
    if (mounted) {
       setState(() => _isLoading = false);
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('已生成过去数据 & ${newWords.length} 个待复习单词'))
       );
    }
  }

  @override
  void dispose() {
    GlobalStatsNotifier.instance.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _userStatsDao.getUserStats();
    
    // Determine bookId
    String bookId = stats.currentBookId;
    if (bookId.isEmpty) {
      bookId = 'waiyan_${stats.currentGrade}_${stats.currentSemester}';
    }
    
    // Fetch book progress
    final bookProg = await _statsDao.getBookProgress(bookId);
    
    // Load manifest if not loaded
    if (_booksManifest.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/books_manifest.json');
        _booksManifest = jsonDecode(jsonStr);
      } catch (e) {
        // Error
      }
    }
    
    if (mounted) {
      setState(() {
        _stats = stats;
        _bookProgress = bookProg;
        _isLoading = false;
      });
    }
  }

  Future<void> _openXhsProfile() async {
    const userId = '5efb6a420000000001005544';
    
    // 按优先级尝试潜在的跳转协议
    final appUris = [
      Uri.parse('xhsuserprofile://user_id=$userId'),
      Uri.parse('xhsdiscover://user/$userId'),
      Uri.parse('xhsdiscover://user/profile/$userId'),
    ];

    final webUri = Uri.parse('https://www.xiaohongshu.com/user/profile/$userId');

    bool launched = false;

    // 1. 尝试直接唤起 App（跳过 canLaunchUrl 检查以进行激进尝试）
    for (final uri in appUris) {
      try {
        // 直接尝试唤起。
        // 注意：在某些 Android 版本上，由于包可见性限制，即便安装了 App，canLaunchUrl 也可能返回 false。
        // 但如果用户授权，launchUrl 显式调用仍然可能成功。
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          launched = true;
          break;
        }
      } catch (e) {
        debugPrint('Failed to launch scheme $uri: $e');
      }
    }

    // 2. 如果唤起 App 失败，打开网页版链接
    if (!launched) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch web profile: $e');
        // 最终兜底：使用应用内浏览器（平台默认方式）
        try {
           await launchUrl(webUri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
             const SizedBox(height: 20),
             // Profile Header
             Container(
               width: 100,
               height: 100,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: AppColors.primary, width: 3),
                 color: AppColors.primary.withValues(alpha: 0.1),
               ),
               child: const Icon(Icons.person, size: 60, color: AppColors.primary),
             ),
             const SizedBox(height: 16),
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 GestureDetector(
                   onTap: _showEditNicknameDialog,
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         _stats?.nickname ?? '学习者',
                         style: GoogleFonts.plusJakartaSans(
                           fontSize: 24,
                           fontWeight: FontWeight.bold,
                           color: AppColors.textHighEmphasis,
                         ),
                       ),
                       const SizedBox(width: 8),
                       const Icon(
                         Icons.mode_edit_outline_rounded,
                         size: 20,
                         color: AppColors.primary,
                       ),
                     ],
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 8),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: AppColors.primary.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Text(
                 'Lv. ${_stats?.currentGrade ?? 3}',
                 style: const TextStyle(
                   color: AppColors.primary,
                   fontWeight: FontWeight.bold,
                   fontSize: 14,
                 ),
               ),
             ),

             const SizedBox(height: 40),

             // Textbook Card with Progress
             _buildCurrentBookCard(),
             const SizedBox(height: 16),
             _buildMenuItem(
               icon: Icons.rocket_launch_rounded,
               title: '参与内测 & 获取更新',
               onTap: _openXhsProfile,
             ),
             const SizedBox(height: 16),
             _buildMenuItem(
               icon: Icons.settings_rounded,
               title: '高级设置',
               onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
               },
             ),
             const SizedBox(height: 16),
             _buildMenuItem(
               icon: Icons.auto_graph_rounded,
               title: '生成模拟数据 (测试用)',
               onTap: _generateMockData,
             ),
             const SizedBox(height: 40),
             Center(
               child: Text(
                 'v1.0.0',
                 style: GoogleFonts.plusJakartaSans(
                   fontSize: 12,
                   color: Colors.grey.shade400,
                   fontWeight: FontWeight.bold,
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBookCard() {
    final percentage = _bookProgress?.percentage ?? 0.0;
    final learned = _bookProgress?.learned ?? 0;
    final total = _bookProgress?.total ?? 0;

    return GestureDetector(
      onTap: _showBookSelectionDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [
             BoxShadow(
                color: AppColors.shadowWhite,
                offset: Offset(0, 8),
                blurRadius: 20,
              )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前教材',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMediumEmphasis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCurrentBookName(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHighEmphasis,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                // Chevron to indicate tappable
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMediumEmphasis),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '总体进度',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 12,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '已掌握 $learned / $total 词',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMediumEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentBookName() {
    if (_stats == null) return '加载中...';
    
    // 1. Try to find by ID
    final bookId = _stats!.currentBookId;
    if (bookId.isNotEmpty && _booksManifest.isNotEmpty) {
      final book = _booksManifest.firstWhere(
        (b) => b['id'] == bookId, 
        orElse: () => null
      );
      if (book != null) {
        return book['name'] as String;
      }
    }
    
    // 2. Try to find by grade/semester (legacy fallback)
    if (_booksManifest.isNotEmpty) {
       final book = _booksManifest.firstWhere(
        (b) => b['grade'] == _stats!.currentGrade && b['semester'] == _stats!.currentSemester,
        orElse: () => null
      );
      if (book != null) {
        return book['name'] as String;
      }
    }

    // 3. Fallback to simple label
    return _getGradeLabel(_stats!.currentGrade, _stats!.currentSemester);
  }

  String _getGradeLabel(int grade, int semester) {
    String gradeStr = '';
    switch (grade) {
      case 7: gradeStr = '七年级'; break;
      case 8: gradeStr = '八年级'; break;
      case 9: gradeStr = '九年级'; break;
      default: gradeStr = '$grade年级';
    }
    String semesterStr = semester == 1 ? '上册' : '下册';
    return '$gradeStr$semesterStr';
  }

  Future<void> _showBookSelectionDialog() async {
    // _booksManifest is already loaded in _loadStats
    final books = _booksManifest;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    Text(
                      '选择教材',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHighEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Divider(height: 1, color: Colors.grey.shade100),
              // Items
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: books.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final id = book['id'];
                    final name = book['name'];
                    final grade = book['grade'];
                    final semester = book['semester'];
                    
                    bool isSelected = (_stats?.currentBookId == id);
                    if (!isSelected && (_stats?.currentBookId.isEmpty ?? true)) {
                      if (_stats?.currentGrade == grade && _stats?.currentSemester == semester) {
                        isSelected = true;
                      }
                    }

                    return InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await _userStatsDao.updateCurrentBook(id, grade, semester);
                        _loadStats();
                        GlobalStatsNotifier.instance.notify();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.textHighEmphasis,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded, color: AppColors.primary, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Safe area padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return BubblyButton(
      onPressed: onTap,
      color: Colors.white,
      shadowColor: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textHighEmphasis,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Future<void> _showEditNicknameDialog() async {
    final TextEditingController controller = TextEditingController(text: _stats?.nickname ?? '');
    
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                   BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 8), blurRadius: 32)
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF), // Blue 50
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mode_edit_outline_rounded, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '修改昵称',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHighEmphasis,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    maxLength: 12,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHighEmphasis
                    ),
                    decoration: InputDecoration(
                      hintText: '请输入新的昵称',
                      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade100, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) => Navigator.pop(context, value),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: AppColors.background,
                          ),
                          child: Text(
                            '取消',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: AppColors.textMediumEmphasis,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BubblyButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isNotEmpty) {
                              Navigator.pop(context, text);
                            }
                          },
                          color: AppColors.primary,
                          shadowColor: AppColors.shadowBlue,
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              '确认修改',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (newNickname != null && newNickname.trim().isNotEmpty && newNickname != _stats?.nickname) {
      final updatedStats = _stats!.copyWith(nickname: newNickname.trim());
      await _userStatsDao.updateUserStats(updatedStats);
      
      // Notify other screens to update (e.g. Home Dashboard)
      GlobalStatsNotifier.instance.notify();
      
      if (mounted) {
        setState(() {
          _stats = updatedStats;
        });
      }
    }
  }
}
