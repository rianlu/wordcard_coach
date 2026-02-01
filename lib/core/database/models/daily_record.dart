class DailyRecord {
  final String date;
  final int newWordsCount;
  final int reviewWordsCount;
  final int correctCount;
  final int wrongCount;
  final int studyMinutes;
  final int createdAt;

  DailyRecord({
    required this.date,
    this.newWordsCount = 0,
    this.reviewWordsCount = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.studyMinutes = 0,
    required this.createdAt,
  });

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        date: json['date'] as String,
        newWordsCount: json['new_words_count'] as int,
        reviewWordsCount: json['review_words_count'] as int,
        correctCount: json['correct_count'] as int,
        wrongCount: json['wrong_count'] as int,
        studyMinutes: json['study_minutes'] as int,
        createdAt: json['created_at'] as int,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'new_words_count': newWordsCount,
        'review_words_count': reviewWordsCount,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'study_minutes': studyMinutes,
        'created_at': createdAt,
      };
}
