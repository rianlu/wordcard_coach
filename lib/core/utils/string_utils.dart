class StringUtils {
  /// Compares two strings "naturally", so that "Module 2" comes before "Module 10".
  static int naturalCompare(String a, String b) {
    final RegExp regex = RegExp(r'(\d+)|(\D+)');
    final Iterable<Match> aMatches = regex.allMatches(a);
    final Iterable<Match> bMatches = regex.allMatches(b);

    final Iterator<Match> aIterator = aMatches.iterator;
    final Iterator<Match> bIterator = bMatches.iterator;

    while (aIterator.moveNext() && bIterator.moveNext()) {
      final String aPart = aIterator.current.group(0)!;
      final String bPart = bIterator.current.group(0)!;

      final int? aInt = int.tryParse(aPart);
      final int? bInt = int.tryParse(bPart);

      if (aInt != null && bInt != null) {
        final int compare = aInt.compareTo(bInt);
        if (compare != 0) return compare;
      } else if (aInt != null) {
        return -1;
      } else if (bInt != null) {
        return 1;
      } else {
        final int compare = aPart.compareTo(bPart);
        if (compare != 0) return compare;
      }
    }

    if (aIterator.moveNext()) return 1;
    if (bIterator.moveNext()) return -1;

    return 0;
  }
}
