import 'dart:math';

/// This work is reproduced here under from code released into the public
/// domain by @brinkler on GitHub:
/// https://github.com/brinkler/levenshtein-dart/blob/master/lib/levenshtein.dart

extension StringLevenshtein on String {
  /// Returns whether there is search similarity between this string and
  /// [otherString]. If true, it means the heuristic algorithm has determined
  /// that the two strings are similar enough to be considered a match.
  bool hasSearchSimilarity(final String otherString,
      {final bool caseSensitive = true}) {
    // If one string can be entirely found within another, they are similar.
    if (contains(otherString) || otherString.contains(this)) return true;

    // Otherwise, use the Levenshtein distance algorithm to determine
    // similarity to account for typographical errors.
    if (levenshteinDistance(otherString) <=
        (max(otherString.length, length) / 1.8).ceil()) return true;

    // Finally resort to checking each individual word for similarity with
    // a custom heuristic based on the Levenshtein distance.
    if (!contains(' ')) return false;

    final thisWords = split(' ');
    final otherWords = otherString.split(' ');

    double perWordAverage = 1;
    for (final String word in thisWords) {
      for (final String otherWord in otherWords) {
        perWordAverage *= (word.levenshteinDistance(otherWord) /
            max(word.length, otherWord.length));
      }
    }

    return perWordAverage < 0.5;
  }

  /// Levenshtein algorithm implementation based on:
  /// http://en.wikipedia.org/wiki/Levenshtein_distance#Iterative_with_two_matrix_rows
  int levenshteinDistance(String otherString,
      {final bool caseSensitive = true}) {
    String thisString = this;
    if (!caseSensitive) {
      thisString = thisString.toLowerCase();
      otherString = otherString.toLowerCase();
    }
    if (thisString == otherString) return 0;
    if (thisString.isEmpty) return otherString.length;
    if (otherString.isEmpty) return thisString.length;

    final List<int> v0 = List<int>.filled(otherString.length + 1, 0);
    final List<int> v1 = List<int>.filled(otherString.length + 1, 0);

    for (int i = 0; i < otherString.length + 1; i < i++) {
      v0[i] = i;
    }

    for (int i = 0; i < thisString.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < otherString.length; j++) {
        final int cost = (thisString[i] == otherString[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }

      for (int j = 0; j < otherString.length + 1; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[otherString.length];
  }
}
