import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/user_stats.dart';
import '../../../../core/database/database_helper.dart';

class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  final UserStatsDao _userStatsDao = UserStatsDao();
  UserStats? _stats;
  bool _isLoading = true;
  List<dynamic> _booksManifest = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _userStatsDao.getUserStats();
    
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
        _isLoading = false;
      });
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
                 color: AppColors.primary.withOpacity(0.1),
               ),
               child: const Icon(Icons.person, size: 60, color: AppColors.primary),
             ),
             const SizedBox(height: 16),
             Text(
               _stats?.nickname ?? 'Friend',
               style: GoogleFonts.plusJakartaSans(
                 fontSize: 24,
                 fontWeight: FontWeight.bold,
                 color: AppColors.textHighEmphasis,
               ),
             ),
             const SizedBox(height: 8),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: AppColors.primary.withOpacity(0.1),
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

             // Menu Items
             _buildMenuItem(
               icon: Icons.book,
               title: '切换教材 (${_getCurrentBookName()})',
               onTap: _showBookSelectionDialog,
             ),
             const SizedBox(height: 16),
             _buildMenuItem(
               icon: Icons.settings_rounded,
               title: '设置',
               onTap: () {}, // TODO
             ),
             const SizedBox(height: 16),
             _buildMenuItem(
               icon: Icons.cloud_sync_rounded,
               title: '更新本地词库 (保留学习进度)',
               onTap: _handleUpdateLibrary,
             ),
             const SizedBox(height: 16),
             _buildMenuItem(
               icon: Icons.help_outline_rounded,
               title: '帮助与反馈',
               onTap: () {}, // TODO
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 500, // Fixed height or flexible
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text(
                '切换教材',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final id = book['id'];
                    final name = book['name'];
                    final grade = book['grade'];
                    final semester = book['semester'];
                    
                    bool isSelected = (_stats?.currentBookId == id);
                    if (!isSelected && (_stats?.currentBookId.isEmpty ?? true)) {
                       // Fallback match by grade/semester
                       if (_stats?.currentGrade == grade && _stats?.currentSemester == semester) {
                         isSelected = true;
                       }
                    }

                    return ListTile(
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _userStatsDao.updateCurrentBook(id, grade, semester);
                        _loadStats();
                      },
                    );
                  },
                ),
              ),
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
              color: AppColors.primary.withOpacity(0.1),
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

  Future<void> _handleUpdateLibrary() async {
    // Show confirmation dialog locally
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                 BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 10), blurRadius: 40)
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // Blue 50
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFDBEAFE).withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                    ]
                  ),
                  child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  '更新词库',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textHighEmphasis,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '这将使用本地最新的 JSON 文件更新词库定义（如释义、例句）。\n\n您的学习进度（掌握程度、打卡记录）将完全保留，不会丢失。',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    height: 1.6,
                    color: AppColors.textMediumEmphasis,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.grey.shade100,
                        ),
                        child: Text(
                          '取消',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            color: AppColors.textMediumEmphasis,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BubblyButton(
                        onPressed: () => Navigator.pop(context, true),
                        color: AppColors.primary,
                        shadowColor: const Color(0xFF1e3a8a),
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            '确认更新',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
    );
    
    if (confirm != true) return;
    
    // Show Loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                 BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 10), blurRadius: 40)
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 24),
                Text(
                  "正在更新...",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHighEmphasis,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
    
    // Perform Update
    try {
       await DatabaseHelper().updateLibraryFromAssets();
       // Artificial delay for UX perception if too fast
       await Future.delayed(const Duration(milliseconds: 800));
    } catch(e) {
       // ignore error
    }
    
    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              '词库已成功更新！',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        elevation: 8,
      )
    );
  }
}
