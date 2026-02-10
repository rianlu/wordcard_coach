import 'dart:convert';

class Word {
  final String id;
  final String text;
  final String meaning;
  final String phonetic;
  final String pos;

  /// 优先返回美式音标，找不到则返回原字符串
  String get displayPhonetic {
    if (phonetic.contains('US:')) {
      final match = RegExp(r'US:\s*(\[[^\]]+\]|[^\]\s]+)').firstMatch(phonetic);
      return match?.group(1)?.trim() ?? phonetic;
    }
    return phonetic.trim();
  }

  final int grade;
  final int semester;
  final String unit;
  final int difficulty;
  final String category;
  final String bookId;
  final int orderIndex; // 教材排序顺序
  final List<String> syllables;
  final List<Map<String, String>> examples; 

  Word({
    required this.id,
    required this.text,
    required this.meaning,
    required this.phonetic,
    this.pos = '',
    required this.grade,
    required this.semester,
    required this.unit,
    required this.difficulty,
    required this.category,
    this.bookId = '',
    this.orderIndex = 0,
    this.syllables = const [],
    this.examples = const [],
  });

  factory Word.fromJson(Map<String, dynamic> json) {
     List<Map<String, String>> examplesList = [];
     if (json['examples'] != null) {
       examplesList = (json['examples'] as List).map((e) => {
         'en': (e['en'] ?? e['text'] ?? '') as String,
         'cn': (e['cn'] ?? e['translation'] ?? '') as String,
       }).toList();
     }

     List<String> syllablesList = [];
     if (json['syllables'] != null) {
       if (json['syllables'] is String) {
         try {
           syllablesList = List<String>.from(jsonDecode(json['syllables']));
         } catch (e) {
           syllablesList = [];
         }
       } else if (json['syllables'] is List) {
         syllablesList = List<String>.from(json['syllables']);
       }
     }
     
     return Word(
         id: json['id'] as String,
         text: json['text'] as String,
         meaning: json['meaning'] as String,
         phonetic: json['phonetic'] as String,
         pos: json['pos'] as String? ?? '',
         grade: json['grade'] as int,
         semester: json['semester'] as int,
         unit: json['unit'] as String,
         difficulty: json['difficulty'] as int,
         category: json['category'] as String,
         bookId: json['book_id'] as String? ?? '',
         orderIndex: json['order_index'] as int? ?? 0,
         syllables: syllablesList,
         examples: examplesList,
       );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'meaning': meaning,
        'phonetic': phonetic,
        'pos': pos,
        'grade': grade,
        'semester': semester,
        'unit': unit,
        'difficulty': difficulty,
        'category': category,
        'book_id': bookId,
        'order_index': orderIndex,
        'syllables': jsonEncode(syllables), 
      };
}
