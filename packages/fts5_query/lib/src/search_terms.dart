/// One unit of a search: a bare word, or a phrase the user wrapped in double
/// quotes.
///
/// Produced by [parseSearch]. A quoted term is matched as written: it is never
/// given a prefix wildcard (see `FtsPrefix`).
final class SearchTerm {
  /// Creates a term. [text] should be non-empty and free of NUL characters;
  /// [parseSearch] guarantees both.
  const SearchTerm(this.text, {this.quoted = false});

  /// The term's text, without the surrounding quotes.
  final String text;

  /// Whether the user wrapped the term in double quotes.
  final bool quoted;

  /// The number of Unicode code points in [text] — what SQLite's `trigram`
  /// tokenizer counts, as opposed to UTF-16 code units (`String.length`).
  int get length => text.runes.length;

  @override
  bool operator ==(Object other) =>
      other is SearchTerm && other.text == text && other.quoted == quoted;

  @override
  int get hashCode => Object.hash(text, quoted);

  @override
  String toString() => quoted ? 'SearchTerm("$text")' : 'SearchTerm($text)';
}

/// Splits search-box [input] into [SearchTerm]s.
///
/// - Terms are separated by any Unicode whitespace.
/// - With [quotedPhrases] (the default), `"harry potter"` is one term. An
///   unclosed quote runs to the end of the input, so a phrase that is still
///   being typed behaves like a finished one. Whitespace inside a phrase is
///   collapsed to single spaces.
/// - NUL characters are removed: SQLite's FTS5 query parser treats one as the
///   end of the string and rejects the query.
/// - Repeated terms are dropped, keeping the first.
/// - At most [maxTerms] terms are returned; the rest of the input is ignored.
///   This bounds the size of the generated SQL, whatever is pasted into the
///   box.
///
/// Returns an empty list for blank input.
List<SearchTerm> parseSearch(
  String input, {
  bool quotedPhrases = true,
  int maxTerms = defaultMaxTerms,
}) {
  if (maxTerms < 1) {
    throw ArgumentError.value(maxTerms, 'maxTerms', 'must be at least 1');
  }
  final cleaned = input.contains('\u0000')
      ? input.replaceAll('\u0000', '')
      : input;

  final terms = <SearchTerm>{};
  final pattern = quotedPhrases ? _wordOrPhrase : _word;
  for (final match in pattern.allMatches(cleaned)) {
    final phrase = quotedPhrases ? match.group(1) : null;
    final term = phrase == null
        ? SearchTerm(match.group(0)!)
        : SearchTerm(phrase.trim().replaceAll(_whitespace, ' '), quoted: true);
    if (term.text.isEmpty) continue;
    terms.add(term);
    if (terms.length == maxTerms) break;
  }
  return List.unmodifiable(terms);
}

/// The default cap on the number of terms [parseSearch] returns.
const int defaultMaxTerms = 32;

final RegExp _whitespace = RegExp(r'\s+', unicode: true);
final RegExp _word = RegExp(r'\S+', unicode: true);
final RegExp _wordOrPhrase = RegExp(r'"([^"]*)"?|[^\s"]+', unicode: true);
