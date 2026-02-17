import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto;
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
  
  static const _keyString = 'WordCardCoachBackupKey2026Secure';
  static const _payloadPrefixV2 = 'WCC2';

  // ---------------------------------------------------------------------------
  // 逻辑处理
  // ---------------------------------------------------------------------------
  
  String _encryptData(String plainText, {required encrypt.IV iv}) {
    final key = encrypt.Key.fromUtf8(_keyString);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String _encryptDataV2(String plainText) {
    final random = Random.secure();
    final ivBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final iv = encrypt.IV(Uint8List.fromList(ivBytes));
    final cipherText = _encryptData(plainText, iv: iv);
    final payloadWithoutMac = '$_payloadPrefixV2:${iv.base64}:$cipherText';
    final mac = _computeMac(payloadWithoutMac);
    return '$payloadWithoutMac:$mac';
  }

  String _decryptDataV2(String encryptedPayload) {
    final key = encrypt.Key.fromUtf8(_keyString);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    if (!encryptedPayload.startsWith('$_payloadPrefixV2:')) {
      throw const FormatException('Unsupported backup format');
    }
    final parts = encryptedPayload.split(':');
    if (parts.length < 4) {
      throw const FormatException('Corrupted backup payload');
    }

    final mac = parts.last;
    final payloadWithoutMac = parts.sublist(0, parts.length - 1).join(':');
    final expectedMac = _computeMac(payloadWithoutMac);
    if (!_constantTimeEquals(mac, expectedMac)) {
      throw const FormatException('Backup integrity check failed');
    }

    final iv = encrypt.IV.fromBase64(parts[1]);
    final cipher = parts.sublist(2, parts.length - 1).join(':');
    return encrypter.decrypt64(cipher, iv: iv);
  }

  String _computeMac(String payload) {
    final keyBytes = utf8.encode(_keyString);
    final payloadBytes = utf8.encode(payload);
    final hmac = crypto.Hmac(crypto.sha256, keyBytes);
    return hmac.convert(payloadBytes).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ---------------------------------------------------------------------------
  // 逻辑处理
  // ---------------------------------------------------------------------------
  
  Future<void> exportData(BuildContext context) async {
    try {
      final db = await _dbHelper.database;
      
      // 逻辑处理
      final userStatsList = await db.query('user_stats');
      final wordProgressList = await db.query('word_progress');
      final dailyRecordsList = await db.query('daily_records');
      
      // 逻辑处理
      final userStatsMap = userStatsList.isNotEmpty ? userStatsList.first : {};
      final accountId = userStatsMap['account_id'] as String? ?? const Uuid().v4();
      final nickname = userStatsMap['nickname'] as String? ?? 'Unknown';
      
      final exportData = {
        'metadata': {
          'version': 2,
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

      // 逻辑处理
      final jsonString = jsonEncode(exportData);
      final encryptedString = _encryptDataV2(jsonString);
      
      // 逻辑处理
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      // 逻辑处理
      final fileName = 'wordcoach_backup_${dateStr}_v2.wcc';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(encryptedString);

      // 逻辑处理
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '这是我的《单词教练》学习进度备份 ($nickname)，请妥善保存。\n请使用《单词教练》App打开此文件。',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
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
  // 逻辑处理
  // ---------------------------------------------------------------------------

  Future<void> importData(BuildContext context) async {
    try {
      // 逻辑处理
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;
      
      final filePath = result.files.single.path!;
      
      // 校验文件扩展名
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
      if (!context.mounted) return;
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
      
      // 逻辑处理
      try {
         jsonMap = jsonDecode(content);
         if (!jsonMap.containsKey('metadata')) {
            // 逻辑处理
            throw const FormatException();
         }
      } catch (_) {
         // 逻辑处理
         try {
           final decrypted = _decryptDataV2(content);
           jsonMap = jsonDecode(decrypted);
         } catch (e) {
           throw Exception('文件已损坏、被篡改，或格式不正确');
         }
      }
      
      // 逻辑处理
      if (!jsonMap.containsKey('metadata') || !jsonMap.containsKey('data')) {
        throw Exception('无效的备份文件格式');
      }
      
      final metadata = jsonMap['metadata'];
      final importedAccountId = metadata['account_id'];
      final importedNickname = metadata['nickname'];
      final importedTimestamp = _asInt(metadata['exported_at']);
      
      // 逻辑处理
      final db = await _dbHelper.database;
      final currentUserList = await db.query('user_stats');
      final currentUser = currentUserList.isNotEmpty ? currentUserList.first : {};
      final currentAccountId = currentUser['account_id'] as String?;
      final currentRows = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM word_progress'));
      
      bool isIdentityMismatch = (currentAccountId != null && importedAccountId != currentAccountId);
      bool hasSignificantData = (currentRows != null && currentRows > 10); // 逻辑处理
      
      bool confirmed = false;

      // 逻辑处理
      if (context.mounted) {
         if (isIdentityMismatch && hasSignificantData) {
            // 逻辑处理
            confirmed = await _showCriticalWarningDialog(context, importedNickname);
         } else {
            // 逻辑处理
            confirmed = await _showNormalConfirmDialog(context, importedNickname, importedTimestamp);
         }
      }
      
      if (!confirmed) return;

      // 逻辑处理
      await _executeRestore(Map<String, dynamic>.from(jsonMap['data'] as Map));
      
      // 逻辑处理
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
        // 逻辑处理
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
      // 逻辑处理
      await txn.delete('word_progress');
      await txn.delete('daily_records');
      await txn.delete('user_stats');
      
      // 逻辑处理
      final userStatsList = _asMapList(data['user_stats']);
      for (var item in userStatsList) {
        await txn.insert('user_stats', item);
      }
      
      // 逻辑处理
      final wordProgressList = _asMapList(data['word_progress']);
      final batch = txn.batch(); // 逻辑处理
      for (var item in wordProgressList) {
        batch.insert('word_progress', item);
      }
      await batch.commit(noResult: true);
      
      // 逻辑处理
      final dailyRecordsList = _asMapList(data['daily_records']);
      for (var item in dailyRecordsList) {
        await txn.insert('daily_records', item);
      }
    });
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
                    color: Color(0xFFEFF6FF), // 配色
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
                    color: Color(0xFFFEF2F2), // 配色
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
