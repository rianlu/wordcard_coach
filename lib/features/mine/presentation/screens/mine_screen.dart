import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/user_stats.dart';

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
               icon: Icons.bar_chart_rounded,
               title: '学习统计',
               onTap: () => Navigator.pushNamed(context, '/statistics'),
             ),
             const SizedBox(height: 16),
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
}
