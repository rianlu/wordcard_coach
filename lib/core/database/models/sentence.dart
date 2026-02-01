class Sentence {
  final String id;
  final String text;
  final String translation;
  final String category;
  final int difficulty;

  Sentence({
    required this.id,
    required this.text,
    required this.translation,
    required this.category,
    required this.difficulty,
  });

  factory Sentence.fromJson(Map<String, dynamic> json) => Sentence(
        id: json['id'] as String,
        text: json['text'] as String,
        translation: json['translation'] as String,
        category: json['category'] as String,
        difficulty: json['difficulty'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'translation': translation,
        'category': category,
        'difficulty': difficulty,
      };
}
