class WordSentenceMap {
  final String wordId;
  final String sentenceId;
  final bool isPrimary;
  final int wordPosition;

  WordSentenceMap({
    required this.wordId,
    required this.sentenceId,
    required this.isPrimary,
    required this.wordPosition,
  });

  factory WordSentenceMap.fromJson(Map<String, dynamic> json) =>
      WordSentenceMap(
        wordId: json['word_id'] as String,
        sentenceId: json['sentence_id'] as String,
        isPrimary: (json['is_primary'] as int) == 1,
        wordPosition: json['word_position'] as int,
      );

  Map<String, dynamic> toJson() => {
        'word_id': wordId,
        'sentence_id': sentenceId,
        'is_primary': isPrimary ? 1 : 0,
        'word_position': wordPosition,
      };
}
