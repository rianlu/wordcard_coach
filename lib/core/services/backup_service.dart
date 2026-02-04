import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../database/database_helper.dart';

import '../services/global_stats_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/bubbly_button.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Hardcoded key for "transparent" app-level encryption. 
  // Ideally this would be more complex, but for this use case it serves to obfuscate the file.
  // 32 chars for AES-256
  static const _keyString = 'WordCardCoachBackupKey2026Secure'; 
  // 16 chars for IV
  static const _ivString = 'WCC_Backup_IV_16'; 

  // ---------------------------------------------------------------------------
  // ENCRYPTION HELPERS
  // ---------------------------------------------------------------------------
  
  String _encryptData(String plainText) {
    final key = encrypt.Key.fromUtf8(_keyString);
    final iv = encrypt.IV.fromUtf8(_ivString);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String _decryptData(String encryptedBase64) {
    final key = encrypt.Key.fromUtf8(_keyString);
    final iv = encrypt.IV.fromUtf8(_ivString);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);
    return decrypted;
  }

  // ---------------------------------------------------------------------------
  // EXPORT
  // ---------------------------------------------------------------------------
  
  Future<void> exportData(BuildContext context) async {
    try {
      final db = await _dbHelper.database;
      
      // 1. Gather Data
      final userStatsList = await db.query('user_stats');
      final wordProgressList = await db.query('word_progress');
      final dailyRecordsList = await db.query('daily_records');
      
      // 2. Prepare Metadata
      final userStatsMap = userStatsList.isNotEmpty ? userStatsList.first : {};
      final accountId = userStatsMap['account_id'] as String? ?? const Uuid().v4();
      final nickname = userStatsMap['nickname'] as String? ?? 'Unknown';
      
      final exportData = {
        'metadata': {
          'version': 1,
          'type': 'encrypted_wcc',
          'exported_at': DateTime.now().millisecondsSinceEpoch,
          'account_id': accountId,
          'nickname': nickname,
          'platform': Platform.operatingSystem,
        },
        'data': {
          'user_stats': userStatsList,
          'word_progress': wordProgressList,
          'daily_records': dailyRecordsList,
        }
      };

      // 3. Serialize and Encrypt
      final jsonString = jsonEncode(exportData);
      final encryptedString = _encryptData(jsonString);
      
      // 4. Write to Temp File with .wcc extension
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      // custom extension .wcc
      final fileName = 'wordcoach_backup_${dateStr}_v1.wcc';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(encryptedString);

      // 5. Share
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '这是我的《单词教练》学习进度备份 ($nickname)，请妥善保存。\n请使用《单词教练》App打开此文件。',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
      
    } catch (e) {
      debugPrint('Export failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // IMPORT
  // ---------------------------------------------------------------------------

  Future<void> importData(BuildContext context) async {
    try {
      // 1. Pick File - Use FileType.any because Android doesn't recognize custom extensions
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;
      
      final filePath = result.files.single.path!;
      
      // Validate file extension
      if (!filePath.endsWith('.wcc') && !filePath.endsWith('.json')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请选择 .wcc 格式的备份文件'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final file = File(filePath);
      await importDataFromFile(file, context);

    } catch (e) {
      debugPrint('Import failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> importDataFromFile(File file, BuildContext context) async {
    try {
      final content = await file.readAsString();
      
      Map<String, dynamic> jsonMap;
      
      // Attempt to deserialize directly first (legacy json support)
      try {
         jsonMap = jsonDecode(content);
         if (!jsonMap.containsKey('metadata')) {
            // If it's valid JSON but not our format, or if it's encrypted data (which isn't valid JSON usually)
            throw const FormatException();
         }
      } catch (_) {
         // Not plain JSON, try decrypting
         try {
           final decrypted = _decryptData(content);
           jsonMap = jsonDecode(decrypted);
         } catch (e) {
           throw Exception('文件已损坏或格式不正确');
         }
      }
      
      // 2. Validate Format
      if (!jsonMap.containsKey('metadata') || !jsonMap.containsKey('data')) {
        throw Exception('无效的备份文件格式');
      }
      
      final metadata = jsonMap['metadata'];
      final importedAccountId = metadata['account_id'];
      final importedNickname = metadata['nickname'];
      final importedTimestamp = metadata['exported_at'] as int;
      
      // 3. Check Identity / Conflict
      final db = await _dbHelper.database;
      final currentUserList = await db.query('user_stats');
      final currentUser = currentUserList.isNotEmpty ? currentUserList.first : {};
      final currentAccountId = currentUser['account_id'] as String?;
      final currentRows = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM word_progress'));
      
      bool isIdentityMismatch = (currentAccountId != null && importedAccountId != currentAccountId);
      bool hasSignificantData = (currentRows != null && currentRows > 10); // Threshold to consider "active user"
      
      bool confirmed = false;

      // 4. Confirm Dialog
      if (context.mounted) {
         if (isIdentityMismatch && hasSignificantData) {
            // CRITICAL WARNING: Different Identity + Current Data Exists
            confirmed = await _showCriticalWarningDialog(context, importedNickname);
         } else {
            // Normal Restore Confirm
            confirmed = await _showNormalConfirmDialog(context, importedNickname, importedTimestamp);
         }
      }
      
      if (!confirmed) return;

      // 5. Execute Restore
      await _executeRestore(jsonMap['data']);
      
      // 6. Success & Refresh
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  '恢复成功！数据已更新',
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
        // Notify UI to refresh
        GlobalStatsNotifier.instance.notify();
      }

    } catch (e) {
      debugPrint('Import from file failed: $e');
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
      rethrow;
    }
  }

  Future<void> _executeRestore(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('word_progress');
      await txn.delete('daily_records');
      await txn.delete('user_stats');
      
      // Restore User Stats
      final userStatsList = List<Map<String, dynamic>>.from(data['user_stats']);
      for (var item in userStatsList) {
        await txn.insert('user_stats', item);
      }
      
      // Restore Word Progress
      final wordProgressList = List<Map<String, dynamic>>.from(data['word_progress']);
      final batch = txn.batch(); // Batch insert for performance
      for (var item in wordProgressList) {
        batch.insert('word_progress', item);
      }
      await batch.commit(noResult: true);
      
      // Restore Daily Records
      final dailyRecordsList = List<Map<String, dynamic>>.from(data['daily_records']);
      for (var item in dailyRecordsList) {
        await txn.insert('daily_records', item);
      }
    });
  }

  Future<bool> _showNormalConfirmDialog(BuildContext context, String? nickname, int timestamp) async {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    
    return await showDialog<bool>(
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
                  child: const Icon(Icons.restore_rounded, color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  '恢复备份',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHighEmphasis,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '即将恢复来自 "$nickname" 的备份\n时间: $dateStr\n\n注意：这将覆盖您当前的学习进度。',
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
                            '确认恢复',
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
    ) ?? false;
  }

  Future<bool> _showCriticalWarningDialog(BuildContext context, String? nickname) async {
    return await showDialog<bool>(
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
                    color: Color(0xFFFEF2F2), // Red 50
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  '警告：用户不匹配',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHighEmphasis,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '此备份属于 "$nickname"，与您当前的账号不同。\n\n⚠️ 如果继续导入，将【彻底删除】您当前设备上的所有学习记录。此操作不可撤销！',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMediumEmphasis,
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: BubblyButton(
                        onPressed: () => Navigator.pop(context, true),
                        color: Colors.red,
                        shadowColor: Colors.red.withValues(alpha: 0.4),
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            '我已知晓，覆盖数据',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        '取消操作',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: AppColors.textMediumEmphasis,
                          fontWeight: FontWeight.w600,
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
    ) ?? false;
  }
}
