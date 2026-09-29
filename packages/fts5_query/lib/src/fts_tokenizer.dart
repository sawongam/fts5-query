/// How the FTS5 table was tokenized, which decides how a search is matched.
///
/// Mirror the table's `tokenize` option:
///
/// | `CREATE VIRTUAL TABLE ... tokenize =`   | `FtsTokenizer`                                      |
/// | --------------------------------------- | --------------------------------------------------- |
/// | `'trigram'`                             | `FtsTokenizer.trigram()`                            |
/// | `'trigram remove_diacritics 1'`         | `FtsTokenizer.trigram()`                            |
/// | `'trigram case_sensitive 1'`            | `FtsTokenizer.trigram(caseSensitive: true)`         |
/// | `'unicode61'`, `'porter'`, `'ascii'`... | `FtsTokenizer.words()`                              |
sealed class FtsTokenizer {
  const FtsTokenizer();

  /// A table tokenized with `trigram`: every term matches as a substring,
  /// anywhere in a column.
  ///
  /// A trigram index cannot look up a term shorter than three characters: in
  /// SQLite such a term inside a `MATCH` matches nothing on its own and is
  /// silently ignored beside other terms. So terms shorter than [minLength]
  /// are searched with `LIKE` (or `GLOB`, when [caseSensitive]) over the
  /// table's stored text instead — which needs the table to have that text:
  /// see `FtsFilter` for contentless tables.
  ///
  /// Set [caseSensitive] when the table was created with
  /// `case_sensitive 1`, so short terms are compared the same way long ones
  /// are.
  const factory FtsTokenizer.trigram({bool caseSensitive, int minLength}) =
      TrigramTokenizer;

  /// A table tokenized into words — `unicode61` (FTS5's default), `porter`,
  /// `ascii`, or a custom tokenizer that splits on word boundaries.
  ///
  /// Every term goes through `MATCH`. [prefix] picks which terms also match
  /// words that merely start with them.
  const factory FtsTokenizer.words({FtsPrefix prefix}) = WordTokenizer;
}

/// Matches terms as substrings through a `trigram` index, falling back to a
/// scan for terms too short to index. See [FtsTokenizer.trigram].
final class TrigramTokenizer extends FtsTokenizer {
  /// See [FtsTokenizer.trigram].
  const TrigramTokenizer({this.caseSensitive = false, this.minLength = 3})
    : assert(minLength >= 1, 'minLength must be at least 1');

  /// Whether the table was created with `case_sensitive 1`. Short terms are
  /// then matched with `GLOB`, which is case-sensitive, rather than `LIKE`.
  final bool caseSensitive;

  /// The shortest term, in Unicode code points, sent to the index.
  ///
  /// Keep the default of 3 for SQLite's built-in `trigram` tokenizer. Only
  /// change it for a custom n-gram tokenizer, to that tokenizer's n: a
  /// shorter term in a `MATCH` does not fail, it is silently ignored.
  final int minLength;

  @override
  bool operator ==(Object other) =>
      other is TrigramTokenizer &&
      other.caseSensitive == caseSensitive &&
      other.minLength == minLength;

  @override
  int get hashCode => Object.hash(TrigramTokenizer, caseSensitive, minLength);

  @override
  String toString() =>
      'FtsTokenizer.trigram(caseSensitive: $caseSensitive, '
      'minLength: $minLength)';
}

/// Matches whole words, optionally by prefix. See [FtsTokenizer.words].
final class WordTokenizer extends FtsTokenizer {
  /// See [FtsTokenizer.words].
  const WordTokenizer({this.prefix = FtsPrefix.last});

  /// Which terms match as a prefix of a word.
  final FtsPrefix prefix;

  @override
  bool operator ==(Object other) =>
      other is WordTokenizer && other.prefix == prefix;

  @override
  int get hashCode => Object.hash(WordTokenizer, prefix);

  @override
  String toString() => 'FtsTokenizer.words(prefix: $prefix)';
}

/// Which terms of a word search match as a prefix (`pot` finds `potter`).
///
/// A term the user put in double quotes is always matched exactly.
enum FtsPrefix {
  /// Every term must match a whole word.
  none,

  /// Only the last term matches as a prefix — the word the user is still
  /// typing in a search-as-you-type box.
  last,

  /// Every term matches as a prefix.
  all,
}
