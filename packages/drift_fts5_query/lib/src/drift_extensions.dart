import 'package:drift/drift.dart';
import 'package:fts5_query/fts5_query.dart';

/// Drift expressions from an [FtsFilter].
extension FtsFilterDrift on FtsFilter {
  /// A typed condition that is true for the rows whose [rowid] is found by
  /// [search], for drift's query builder.
  ///
  /// [rowid] is the expression equal to the FTS row's rowid — usually the
  /// content table's `rowId` or its integer primary key:
  ///
  /// ```dart
  /// final bookSearch = FtsFilter(
  ///   table: 'books_fts',
  ///   columns: ['title', 'author'],
  /// );
  ///
  /// final query = select(books)
  ///   ..where((b) => bookSearch.matches(input, rowid: b.id));
  /// ```
  ///
  /// A blank [search] gives a constant `TRUE`, so the query lists every row
  /// and needs no branch at the call site. Use [where] instead if you would
  /// rather receive `null`.
  ///
  /// A stream query (`watch()`) re-runs when a table it reads changes. The
  /// FTS5 table is read inside a subquery drift cannot see, so pass it — its
  /// drift table, when it is declared in a `.drift` file — as
  /// [watchedTables] if it can change without the queried table changing.
  /// With triggers that copy the content table into the index, which is the
  /// usual setup, the queried table already covers it.
  Expression<bool> matches(
    String search, {
    required Expression<Object> rowid,
    Iterable<ResultSetImplementation<Object?, Object?>> watchedTables =
        const [],
  }) {
    final subquery = this.subquery(search);
    if (subquery == null) return const Constant(true);
    return _FtsMatchExpression(rowid, subquery, List.of(watchedTables));
  }
}

/// Drift variables for an [FtsClause].
extension FtsClauseDrift on FtsClause {
  /// The clause's [FtsClause.arguments] as drift variables, in placeholder
  /// order, for `customSelect` and `customStatement`:
  ///
  /// ```dart
  /// final clause = bookSearch.where(input, rowid: 'b.rowid');
  /// db.customSelect(
  ///   'SELECT * FROM books b'
  ///   '${clause == null ? '' : ' WHERE ${clause.sql}'}',
  ///   variables: clause?.variables ?? const [],
  ///   readsFrom: {db.books},
  /// );
  /// ```
  List<Variable<String>> get variables => [
    for (final argument in arguments) Variable<String>(argument),
  ];

  /// The clause as a drift expression of type [T], each argument bound as a
  /// variable — `Expression<bool>` for [FtsFilter.where] and
  /// [FtsFilter.condition].
  ///
  /// Only valid where drift writes it into a SQLite statement.
  Expression<T> toExpression<T extends Object>({
    Precedence precedence = Precedence.unknown,
  }) => _FtsClauseExpression<T>(this, precedence);
}

/// `<rowid> IN (<subquery>)`, with the rowid written by drift so it follows
/// the query's table aliases.
final class _FtsMatchExpression extends Expression<bool> {
  _FtsMatchExpression(this.rowid, this.subquery, this.watchedTables);

  final Expression<Object> rowid;
  final FtsClause subquery;
  final List<ResultSetImplementation<Object?, Object?>> watchedTables;

  @override
  Precedence get precedence => Precedence.comparisonEq;

  @override
  void writeInto(GenerationContext context) {
    writeInner(context, rowid);
    context.buffer.write(' IN (');
    _writeClause(context, subquery);
    context.buffer.write(')');
    context.watchedTables.addAll(watchedTables);
  }

  @override
  bool operator ==(Object other) =>
      other is _FtsMatchExpression &&
      other.rowid == rowid &&
      other.subquery == subquery;

  @override
  int get hashCode => Object.hash(rowid, subquery);
}

final class _FtsClauseExpression<T extends Object> extends Expression<T> {
  _FtsClauseExpression(this.clause, this.precedence);

  final FtsClause clause;

  @override
  final Precedence precedence;

  @override
  void writeInto(GenerationContext context) => _writeClause(context, clause);

  @override
  bool operator ==(Object other) =>
      other is _FtsClauseExpression<T> && other.clause == clause;

  @override
  int get hashCode => Object.hash(_FtsClauseExpression, clause);
}

void _writeClause(GenerationContext context, FtsClause clause) =>
    clause.writeTo(
      sql: context.buffer.write,
      argument: (value) => Variable<String>(value).writeInto(context),
    );
