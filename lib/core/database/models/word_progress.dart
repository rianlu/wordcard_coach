class WordProgress {
  final String id;
  final String wordId;
  final double easinessFactor;
  final int interval;
  final int repetition;
  final int nextReviewDate;
  final int lastReviewDate;
  final int reviewCount;
  final int correctCount;
  final int wrongCount;
  final int masteryLevel;
  final int selectModeCount;
  final int spellModeCount;
  final int speakModeCount;
  final int createdAt;
  final int updatedAt;

  WordProgress({
    required this.id,
    required this.wordId,
    this.easinessFactor = 2.5,
    this.interval = 1,
    this.repetition = 0,
    this.nextReviewDate = 0,
    this.lastReviewDate = 0,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.masteryLevel = 0,
    this.selectModeCount = 0,
    this.spellModeCount = 0,
    this.speakModeCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WordProgress.fromJson(Map<String, dynamic> json) => WordProgress(
        id: json['id'] as String,
        wordId: json['word_id'] as String,
        easinessFactor: (json['easiness_factor'] as num).toDouble(),
        interval: json['interval'] as int,
        repetition: json['repetition'] as int,
        nextReviewDate: json['next_review_date'] as int,
        lastReviewDate: json['last_review_date'] as int,
        reviewCount: json['review_count'] as int,
        correctCount: json['correct_count'] as int,
        wrongCount: json['wrong_count'] as int,
        masteryLevel: json['mastery_level'] as int,
        selectModeCount: json['select_mode_count'] as int,
        spellModeCount: json['spell_mode_count'] as int,
        speakModeCount: json['speak_mode_count'] as int,
        createdAt: json['created_at'] as int,
        updatedAt: json['updated_at'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'word_id': wordId,
        'easiness_factor': easinessFactor,
        'interval': interval,
        'repetition': repetition,
        'next_review_date': nextReviewDate,
        'last_review_date': lastReviewDate,
        'review_count': reviewCount,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'mastery_level': masteryLevel,
        'select_mode_count': selectModeCount,
        'spell_mode_count': spellModeCount,
        'speak_mode_count': speakModeCount,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
