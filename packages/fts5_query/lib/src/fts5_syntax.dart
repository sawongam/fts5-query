/// Low-level escaping for the pieces of an FTS5 search.
///
/// `FtsFilter` is built from these. Use them directly when you assemble your
/// own SQL; every function returns a value to **bind as a parameter**, never
/// to splice into the statement.
abstract final class Fts5Syntax {
  /// [text] as an FTS5 string: in double quotes, with inner quotes doubled.
  ///
  /// Inside a string, FTS5 treats `AND`, `OR`, `NOT`, `NEAR`, `*`, `^`, `:`,
  /// parentheses and column names as plain text, so user input cannot change
  /// the shape of the query. A string of several tokens is a phrase: its
  /// tokens must appear next to each other, in order.
  ///
  /// ```dart
  /// Fts5Syntax.phrase('C++ "draft" OR x'); // '"C++ ""draft"" OR x"'
  /// ```
  static String phrase(String text) => '"${text.replaceAll('"', '""')}"';

  /// [text] as a prefix query: [phrase] followed by `*`, so `pot` also
  /// matches `potter`. For a word tokenizer only — under `trigram` every
  /// phrase already matches as a substring.
  static String prefixPhrase(String text) => '${phrase(text)}*';

  /// An FTS5 column filter restricting what follows it to [columns]:
  /// `{"title" "author"} : `.
  ///
  /// [columns] are the columns' plain names, not SQL-quoted identifiers.
  static String columnFilter(Iterable<String> columns) =>
      '{${columns.map(phrase).join(' ')}} : ';

  /// A `LIKE` pattern matching any value that contains [text], for use with
  /// `ESCAPE '\'`.
  ///
  /// `%`, `_` and `\` in [text] are escaped, so they match themselves.
  static String likeContains(String text) => '%${escapeLike(text)}%';

  /// [text] with the `LIKE` wildcards `%` and `_`, and the escape character
  /// `\`, escaped with `\`. Pair with `ESCAPE '\'`.
  static String escapeLike(String text) =>
      text.replaceAllMapped(_likeSpecial, (match) => '\\${match[0]}');

  /// A `GLOB` pattern matching any value that contains [text].
  ///
  /// `*`, `?` and `[` in [text] are wrapped in brackets, so they match
  /// themselves. `GLOB` is case-sensitive and needs no `ESCAPE` clause.
  static String globContains(String text) => '*${escapeGlob(text)}*';

  /// [text] with the `GLOB` metacharacters `*`, `?` and `[` bracketed.
  static String escapeGlob(String text) =>
      text.replaceAllMapped(_globSpecial, (match) => '[${match[0]}]');

  static final RegExp _likeSpecial = RegExp(r'[\\%_]');
  static final RegExp _globSpecial = RegExp(r'[*?[]');
}
