import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _userStatsDao.getUserStats();
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
               title: '切换教材 (${_getGradeLabel(_stats?.currentGrade ?? 7, _stats?.currentSemester ?? 1)})',
               onTap: _showGradeSelectionDialog,
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

  void _showGradeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '切换教材',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildGradeOption(7, 1),
              _buildGradeOption(7, 2),
              _buildGradeOption(8, 1),
              _buildGradeOption(8, 2),
              _buildGradeOption(9, 1),
              _buildGradeOption(9, 2),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGradeOption(int grade, int semester) {
    bool isSelected = (_stats?.currentGrade == grade && _stats?.currentSemester == semester);
    // Handle nulls safely
    if (_stats != null) {
        isSelected = (_stats!.currentGrade == grade && _stats!.currentSemester == semester);
    }
    
    return ListTile(
      title: Text(_getGradeLabel(grade, semester)),
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? AppColors.primary : Colors.grey,
      ),
      onTap: () async {
        Navigator.pop(context);
        await _userStatsDao.updateGrade(grade, semester);
        _loadStats();
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
