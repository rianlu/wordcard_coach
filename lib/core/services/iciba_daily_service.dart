import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 说明：逻辑说明
/// 说明：逻辑说明
class IcibaDailyService {
  static final IcibaDailyService _instance = IcibaDailyService._internal();
  factory IcibaDailyService() => _instance;
  IcibaDailyService._internal();

  static const String _apiUrl = 'https://open.iciba.com/dsapi/';
  static const String _cacheKey = 'iciba_daily_cache';
  static const String _cacheTimeKey = 'iciba_daily_cache_time';
  
  /// 说明：逻辑说明
  DailySentence? _cachedSentence;
  
  /// 说明：逻辑说明
  Future<DailySentence?> getTodaySentence() async {
    // 说明：逻辑说明
    if (_cachedSentence != null) {
      return _cachedSentence;
    }
    
    // 说明：逻辑说明
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    final cachedTime = prefs.getInt(_cacheTimeKey) ?? 0;
    
    // 说明：逻辑说明
    final now = DateTime.now();
    final cacheDate = DateTime.fromMillisecondsSinceEpoch(cachedTime);
    final isToday = now.year == cacheDate.year && 
                    now.month == cacheDate.month && 
                    now.day == cacheDate.day;
    
    if (cachedJson != null && isToday) {
      try {
        _cachedSentence = DailySentence.fromJson(jsonDecode(cachedJson));
        return _cachedSentence;
      } catch (e) {
        debugPrint('Error parsing cached sentence: $e');
      }
    }
    
    // 说明：逻辑说明
    return await _fetchNewSentence(prefs);
  }
  
  /// 说明：逻辑说明
  Future<DailySentence?> refreshSentence() async {
    final prefs = await SharedPreferences.getInstance();
    return await _fetchNewSentence(prefs);
  }
  
  /// 说明：逻辑说明
  Future<DailySentence?> _fetchNewSentence(SharedPreferences prefs) async {
    try {
      final uri = Uri.parse(_apiUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // 说明：逻辑说明
        // 说明：逻辑说明
        final String body = utf8.decode(response.bodyBytes);
        final data = jsonDecode(body);
        final sentence = DailySentence.fromJson(data);
        
        // 说明：逻辑说明
        await prefs.setString(_cacheKey, jsonEncode(data));
        await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        
        _cachedSentence = sentence;
        return sentence;
      }
    } catch (e) {
      debugPrint('Error fetching iciba daily: $e');
    }
    
    // 说明：逻辑说明
    return _getFallbackSentence();
  }
  
  /// 说明：逻辑说明
  DailySentence _getFallbackSentence() {
    return DailySentence(
      id: '0',
      englishContent: 'Every accomplishment starts with the decision to try.',
      chineseNote: '每一个成就都始于尝试的决定。',
      audioUrl: null,
      imageUrl: null,
      shareImageUrl: null,
      date: DateTime.now().toString().substring(0, 10),
    );
  }
}

/// 说明：逻辑说明
class DailySentence {
  final String id;
  final String englishContent;
  final String chineseNote;
  final String? audioUrl;
  final String? imageUrl;         // 说明：逻辑说明
  final String? shareImageUrl;    // 说明：逻辑说明
  final String date;
  
  DailySentence({
    required this.id,
    required this.englishContent,
    required this.chineseNote,
    this.audioUrl,
    this.imageUrl,
    this.shareImageUrl,
    required this.date,
  });
  
  factory DailySentence.fromJson(Map<String, dynamic> json) {
    String? tts = json['tts']?.toString().trim();
    if (tts == null || tts.isEmpty) tts = null;

    return DailySentence(
      id: json['sid']?.toString() ?? '0',
      englishContent: json['content']?.toString().trim() ?? '',
      chineseNote: json['note']?.toString().trim() ?? '',
      audioUrl: tts,
      imageUrl: json['picture']?.toString() ?? json['picture2']?.toString(),
      shareImageUrl: json['fenxiang_img']?.toString(),
      date: json['dateline']?.toString().trim() ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'sid': id,
      'content': englishContent,
      'note': chineseNote,
      'tts': audioUrl,
      'picture': imageUrl,
      'fenxiang_img': shareImageUrl,
      'dateline': date,
    };
  }
}
