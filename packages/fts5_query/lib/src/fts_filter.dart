import 'fts5_syntax.dart';
import 'fts_clause.dart';
import 'fts_tokenizer.dart';
import 'search_terms.dart';
import 'sql_identifier.dart';

/// Turns what a user typed into a search box into a safe SQLite FTS5 filter.
///
/// Configure one per FTS5 table, once, and reuse it:
///
/// ```dart
/// final bookSearch = FtsFilter(
///   table: 'books_fts',
///   columns: ['title', 'author'],
/// );
///
/// final clause = bookSearch.where(input, rowid: 'b.rowid');
/// final sql = 'SELECT * FROM books b'
///     '${clause == null ? '' : ' WHERE ${clause.sql}'}';
/// db.select(sql, clause?.arguments ?? const []);
/// ```
///
/// ## What a search means
///
/// The input is split into terms ([parseSearch]): words, and phrases in
/// double quotes. With [FtsCombine.all], a row matches when **every** term
/// appears in at least one of [columns] — `potter rowling` finds the book
/// whose title has one word and whose author has the other. Every term is
/// bound as an FTS5 string, so `AND`, `NEAR`, `*`, `:` or a stray quote in
/// the input are searched for as text and can never break or reshape the
/// query.
///
/// Blank input produces no clause (`null`), so the caller adds no condition
/// and lists everything.
///
/// ## Trigram tables and short terms
///
/// With [FtsTokenizer.trigram] (the default), terms of three or more
/// characters go through the index. Shorter ones cannot — in SQLite a
/// one- or two-character phrase inside `MATCH` is silently ignored — so they
/// are matched with `LIKE` over the stored text of [columns]. Two things
/// follow from that:
///
/// - **The table must store its text.** A normal FTS5 table or an
///   external-content one (`content='books'`) works. A contentless table
///   (`content=''`) has no text to scan, so a short term matches nothing.
/// - **Short terms compare more strictly.** `LIKE` folds case for ASCII
///   letters only, and does not apply the tokenizer's `remove_diacritics`.
///   A long term `ÉCOLE` finds `école`; a short term `É` does not find `é`,
///   and `e` does not find `é`. ASCII text behaves identically either way.
///
/// ## Identifiers are trusted
///
/// [table], [columns] and the `rowid` passed to [where] are written into the
/// SQL as they are: they are **identifiers chosen by the developer, never
/// user input**. They are checked to be plain or double-quoted SQL
/// identifiers, and anything else throws an [ArgumentError] — but that is a
/// guard against mistakes, not a license to pass a name taken from a request.
final class FtsFilter {
  /// Creates a filter over the FTS5 [table], searching [columns].
  ///
  /// [table] may be schema-qualified (`main.books_fts`). [columns] must be
  /// columns of that table; list every indexed column to search all of
  /// them. The index is restricted to these columns too, so a long term and a
  /// short one search the same places.
  ///
  /// [tokenizer] must mirror the table's `tokenize` option. With
  /// [quotedPhrases], double quotes group words into one phrase; turn it off
  /// to treat `"` as an ordinary character. At most [maxTerms] terms are
  /// used; see [parseSearch].
  ///
  /// Throws an [ArgumentError] if an identifier is malformed, [columns] is
  /// empty, or [maxTerms] is less than one.
  FtsFilter({
    required String table,
    required Iterable<String> columns,
    this.tokenizer = const FtsTokenizer.trigram(),
    this.combine = FtsCombine.all,
    this.quotedPhrases = true,
    this.maxTerms = defaultMaxTerms,
  }) : table = checkIdentifier(table, 'table', maxParts: 2),
       columns = List.unmodifiable([
         for (final column in columns) checkIdentifier(column, 'columns'),
       ]) {
    if (this.columns.isEmpty) {
      throw ArgumentError.value(columns, 'columns', 'must not be empty');
    }
    if (maxTerms < 1) {
      throw ArgumentError.value(maxTerms, 'maxTerms', 'must be at least 1');
    }
    _matchColumn = lastPart(this.table);
    _columnFilter = Fts5Syntax.columnFilter(this.columns.map(unquote));
  }

  /// The FTS5 table, as written into the SQL.
  final String table;

  /// The searched columns, as written into the SQL.
  final List<String> columns;

  /// How the table was tokenized.
  final FtsTokenizer tokenizer;

  /// Whether a row must match every term or any of them.
  final FtsCombine combine;

  /// Whether double quotes group words into a phrase.
  final bool quotedPhrases;

  /// The most terms a search uses.
  final int maxTerms;

  late final String _matchColumn;
  late final String _columnFilter;

  /// The terms [search] is split into, as this filter would use them.
  List<SearchTerm> terms(String search) =>
      parseSearch(search, quotedPhrases: quotedPhrases, maxTerms: maxTerms);

  /// A condition on another table's rows, or `null` for a blank [search]:
  ///
  /// ```sql
  /// <rowid> IN (SELECT rowid FROM <table> WHERE ...)
  /// ```
  ///
  /// [rowid] is the expression, in the outer query, that equals the FTS row's
  /// rowid — usually the content table's `rowid` or its `INTEGER PRIMARY
  /// KEY`, qualified by its alias: `b.rowid`, `books.id`. It is a trusted
  /// identifier, like [table].
  ///
  /// ```dart
  /// final clause = bookSearch.where(input, rowid: 'b.rowid');
  /// ```
  FtsClause? where(String search, {required String rowid}) {
    checkIdentifier(rowid, 'rowid', maxParts: 3);
    final inner = subquery(search);
    if (inner == null) return null;
    return (FtsClauseBuilder()
          ..sql('$rowid IN (')
          ..clause(inner)
          ..sql(')'))
        .build();
  }

  /// `SELECT rowid FROM <table> WHERE ...`: the rowids of the matching rows,
  /// or `null` for a blank [search].
  ///
  /// Use it to join, or to build the `IN` yourself.
  FtsClause? subquery(String search) {
    final condition = this.condition(search);
    if (condition == null) return null;
    return (FtsClauseBuilder()
          ..sql('SELECT rowid FROM $table WHERE ')
          ..clause(condition))
        .build();
  }

  /// The bare condition, for a query that reads the FTS5 table itself — to
  /// rank by relevance or call `highlight()` — or `null` for a blank
  /// [search].
  ///
  /// ```dart
  /// final clause = bookSearch.condition(input)!;
  /// db.select(
  ///   "SELECT rowid, highlight(books_fts, 0, '[', ']') FROM books_fts "
  ///   'WHERE ${clause.sql} '
  ///   '${clause.canRank ? 'ORDER BY rank' : ''}',
  ///   clause.arguments,
  /// );
  /// ```
  ///
  /// `rank` and the auxiliary functions work only when
  /// [FtsClause.canRank] is true.
  FtsClause? condition(String search) {
    final terms = this.terms(search);
    if (terms.isEmpty) return null;

    final indexed = <String>[];
    final scanned = <SearchTerm>[];
    final tokenizer = this.tokenizer;
    switch (tokenizer) {
      case TrigramTokenizer(:final minLength):
        for (final term in terms) {
          if (term.length >= minLength) {
            indexed.add(Fts5Syntax.phrase(term.text));
          } else {
            scanned.add(term);
          }
        }
      case WordTokenizer(:final prefix):
        for (var i = 0; i < terms.length; i++) {
          final term = terms[i];
          final asPrefix =
              !term.quoted &&
              switch (prefix) {
                FtsPrefix.none => false,
                FtsPrefix.last => i == terms.length - 1,
                FtsPrefix.all => true,
              };
          indexed.add(
            asPrefix
                ? Fts5Syntax.prefixPhrase(term.text)
                : Fts5Syntax.phrase(term.text),
          );
        }
    }

    final any = combine == FtsCombine.any;
    final builder = FtsClauseBuilder();
    // Parenthesized when it has several parts, so the caller can AND it into
    // a larger WHERE without the ORs of `any` mode binding to their terms.
    final compound = (indexed.isEmpty ? 0 : 1) + scanned.length > 1;
    if (compound) builder.sql('(');
    var first = true;
    void separator() {
      if (!first) builder.sql(any ? ' OR ' : ' AND ');
      first = false;
    }

    if (indexed.isNotEmpty) {
      separator();
      final query = '$_columnFilter(${indexed.join(any ? ' OR ' : ' AND ')})';
      // SQLite cannot evaluate MATCH as one branch of an OR, so in `any`
      // mode with scanned terms beside it, the MATCH moves into a subquery.
      if (any && scanned.isNotEmpty) {
        builder
          ..sql('rowid IN (SELECT rowid FROM $table WHERE $_matchColumn MATCH ')
          ..argument(query)
          ..sql(')');
      } else {
        builder
          ..sql('$_matchColumn MATCH ')
          ..argument(query)
          ..markRankable();
      }
    }

    final caseSensitive =
        tokenizer is TrigramTokenizer && tokenizer.caseSensitive;
    for (final term in scanned) {
      separator();
      final pattern = caseSensitive
          ? Fts5Syntax.globContains(term.text)
          : Fts5Syntax.likeContains(term.text);
      builder.sql('(');
      for (var i = 0; i < columns.length; i++) {
        if (i > 0) builder.sql(' OR ');
        builder
          ..sql(caseSensitive ? '${columns[i]} GLOB ' : '${columns[i]} LIKE ')
          ..argument(pattern);
        if (!caseSensitive) builder.sql(r" ESCAPE '\'");
      }
      builder.sql(')');
    }

    if (compound) builder.sql(')');
    return builder.build();
  }

  @override
  String toString() =>
      'FtsFilter(table: $table, columns: $columns, tokenizer: $tokenizer, '
      'combine: $combine)';
}

/// Whether a row must match every search term, or any one of them.
enum FtsCombine {
  /// Every term must match — the usual search-box behaviour, where each
  /// extra word narrows the results.
  all,

  /// At least one term must match; each extra word widens the results.
  any,
}
