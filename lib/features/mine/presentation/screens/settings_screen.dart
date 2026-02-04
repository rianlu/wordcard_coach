import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '高级设置',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: AppColors.textHighEmphasis
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHighEmphasis),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            _buildSectionHeader('数据管理'),
            const SizedBox(height: 12),
            _buildBubblyMenuItem(
              icon: Icons.upload_file_rounded,
              iconColor: Colors.blue,
              title: '备份学习进度 (导出)',
              subtitle: '将进度保存为文件，推荐发送到微信文件传输助手备份',
              onTap: () async {
                await BackupService().exportData(context);
              },
            ),
            const SizedBox(height: 16),
            _buildBubblyMenuItem(
              icon: Icons.download_rounded,
              iconColor: Colors.green,
              title: '恢复学习进度 (导入)',
              subtitle: '从备份文件恢复，请谨慎操作',
              onTap: () async {
                await BackupService().importData(context);
              },
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('词库管理'),
            const SizedBox(height: 12),
             _buildBubblyMenuItem(
               icon: Icons.cloud_sync_rounded,
               iconColor: AppColors.primary,
               title: '更新本地词库',
               subtitle: '保留学习进度，仅更新释义和例句',
               onTap: _handleUpdateLibrary,
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildBubblyMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return BubblyButton(
      onPressed: onTap,
      color: Colors.white,
      shadowColor: Colors.grey.shade200,
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHighEmphasis,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMediumEmphasis,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
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
          constraints: const BoxConstraints(maxWidth: 380),
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
                  child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  '更新词库',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHighEmphasis,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '这将使用本地最新的 JSON 文件更新词库定义（如释义、例句）。\n\n您的学习进度将完全保留，不会丢失。',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMediumEmphasis,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
                        color: AppColors.primary,
                        shadowColor: AppColors.shadowBlue,
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            '确认更新',
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
    );
    
    if (confirm != true) return;
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 8), blurRadius: 32)
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  "正在更新...",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
