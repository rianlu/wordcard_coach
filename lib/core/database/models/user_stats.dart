class UserStats {
  final int id;
  final String nickname;
  final int currentGrade;
  final int currentSemester;
  final String currentBookId;
  final int totalWordsLearned;
  final int totalWordsMastered;
  final int totalReviews;
  final int totalCorrect;
  final int totalWrong;
  final int continuousDays;
  final int totalStudyDays;
  final String lastStudyDate;
  final int totalStudyMinutes;
  final int updatedAt;

  UserStats({
    this.id = 1,
    this.nickname = '学习者',
    this.currentGrade = 3,
    this.currentSemester = 1,
    this.currentBookId = '',
    this.totalWordsLearned = 0,
    this.totalWordsMastered = 0,
    this.totalReviews = 0,
    this.totalCorrect = 0,
    this.totalWrong = 0,
    this.continuousDays = 0,
    this.totalStudyDays = 0,
    this.lastStudyDate = '',
    this.totalStudyMinutes = 0,
    required this.updatedAt,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        id: json['id'] as int,
        nickname: json['nickname'] as String,
        currentGrade: json['current_grade'] as int,
        currentSemester: json['current_semester'] as int,
        currentBookId: json['current_book_id'] as String? ?? '',
        totalWordsLearned: json['total_words_learned'] as int,
        totalWordsMastered: json['total_words_mastered'] as int,
        totalReviews: json['total_reviews'] as int,
        totalCorrect: json['total_correct'] as int,
        totalWrong: json['total_wrong'] as int,
        continuousDays: json['continuous_days'] as int,
        totalStudyDays: json['total_study_days'] as int,
        lastStudyDate: json['last_study_date'] as String,
        totalStudyMinutes: json['total_study_minutes'] as int,
        updatedAt: json['updated_at'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'current_grade': currentGrade,
        'current_semester': currentSemester,
        'current_book_id': currentBookId,
        'total_words_learned': totalWordsLearned,
        'total_words_mastered': totalWordsMastered,
        'total_reviews': totalReviews,
        'total_correct': totalCorrect,
        'total_wrong': totalWrong,
        'continuous_days': continuousDays,
        'total_study_days': totalStudyDays,
        'last_study_date': lastStudyDate,
        'total_study_minutes': totalStudyMinutes,
        'updated_at': updatedAt,
      };

  UserStats copyWith({
    int? id,
    String? nickname,
    int? currentGrade,
    int? currentSemester,
    String? currentBookId,
    int? totalWordsLearned,
    int? totalWordsMastered,
    int? totalReviews,
    int? totalCorrect,
    int? totalWrong,
    int? continuousDays,
    int? totalStudyDays,
    String? lastStudyDate,
    int? totalStudyMinutes,
    int? updatedAt,
  }) {
    return UserStats(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      currentGrade: currentGrade ?? this.currentGrade,
      currentSemester: currentSemester ?? this.currentSemester,
      currentBookId: currentBookId ?? this.currentBookId,
      totalWordsLearned: totalWordsLearned ?? this.totalWordsLearned,
      totalWordsMastered: totalWordsMastered ?? this.totalWordsMastered,
      totalReviews: totalReviews ?? this.totalReviews,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalWrong: totalWrong ?? this.totalWrong,
      continuousDays: continuousDays ?? this.continuousDays,
      totalStudyDays: totalStudyDays ?? this.totalStudyDays,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      totalStudyMinutes: totalStudyMinutes ?? this.totalStudyMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
