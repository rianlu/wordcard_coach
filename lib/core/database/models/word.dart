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
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: json['id'] as String,
        text: json['text'] as String,
        meaning: json['meaning'] as String,
        phonetic: json['phonetic'] as String,
        grade: json['grade'] as int,
        semester: json['semester'] as int,
        unit: json['unit'] as String,
        difficulty: json['difficulty'] as int,
        category: json['category'] as String,
      );

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
      };
}
