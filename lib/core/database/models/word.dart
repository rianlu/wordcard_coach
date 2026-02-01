import 'dart:convert';

class Word {
  final String id;
  final String text;
  final String meaning;
  final String phonetic;
  final int grade;
  final int semester;
  final String unit;
  final int difficulty;
  final String category;
  final List<String> syllables;
  final List<Map<String, String>> examples; 

  Word({
    required this.id,
    required this.text,
    required this.meaning,
    required this.phonetic,
    required this.grade,
    required this.semester,
    required this.unit,
    required this.difficulty,
    required this.category,
    this.syllables = const [],
    this.examples = const [],
  });

  factory Word.fromJson(Map<String, dynamic> json) {
     List<Map<String, String>> examplesList = [];
     if (json['examples'] != null) {
       for (var item in json['examples']) {
         examplesList.add({
           'en': item['text'] ?? '',
           'cn': item['translation'] ?? ''
         });
       }
     }
     
     List<String> syllablesList = [];
     if (json['syllables'] != null) {
       if (json['syllables'] is String) {
          // If stored as JSON string in DB
          try {
             var decoded = jsonDecode(json['syllables']);
            if (decoded is List) {
              syllablesList = List<String>.from(decoded);
            }
          } catch(e) {
            // fallback if comma separated or failed
            syllablesList = [];
          }
       } else if (json['syllables'] is List) {
         // If passed directly from JSON seed
         syllablesList = List<String>.from(json['syllables']);
       }
     }
     
     return Word(
        id: json['id'] as String,
        text: json['text'] as String,
        meaning: json['meaning'] as String,
        phonetic: json['phonetic'] as String,
        grade: json['grade'] as int,
        semester: json['semester'] as int,
        unit: json['unit'] as String,
        difficulty: json['difficulty'] as int,
        category: json['category'] as String,
        syllables: syllablesList,
        examples: examplesList,
      );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'meaning': meaning,
        'phonetic': phonetic,
        'grade': grade,
        'semester': semester,
        'unit': unit,
        'difficulty': difficulty,
        'category': category,
        'syllables': jsonEncode(syllables), // Store as JSON string
        // examples not usually stored back to words table json unless we custom handle it
      };
}
