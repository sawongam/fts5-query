import 'package:drift/drift.dart';
import 'package:drift_fts5_query/drift_fts5_query.dart';
import 'package:test/test.dart';

import 'src/database.dart';

void main() {
  late TestDatabase db;
  final bookSearch = FtsFilter(
    table: 'books_fts',
    columns: ['title', 'author'],
  );

  setUp(() async {
    db = TestDatabase();
    await db.batch((batch) {
      batch.insertAll(db.books, [
        BooksCompanion.insert(
          id: const Value(1),
          title: 'Harry Potter',
          author: 'J. K. Rowling',
        ),
        BooksCompanion.insert(
          id: const Value(2),
          title: 'Café Crème',
          author: 'Émile Zola',
        ),
        BooksCompanion.insert(
          id: const Value(3),
          title: 'Pi',
          author: 'Yann Martel',
        ),
        BooksCompanion.insert(
          id: const Value(4),
          title: 'Potter Wasp Field Guide',
          author: 'Anon',
          archived: const Value(true),
        ),
      ]);
    });
  });

  tearDown(() => db.close());

  Future<List<int>> ids(String input, {bool archived = false}) async {
    final query = db.select(db.books)
      ..where((b) => bookSearch.matches(input, rowid: b.id))
      ..where((b) => b.archived.equals(archived))
      ..orderBy([(b) => OrderingTerm(expression: b.id)]);
    return [for (final book in await query.get()) book.id];
  }

  group('FtsFilter.matches', () {
    test('filters a query-builder select', () async {
      expect(await ids('potter'), [1]);
      expect(await ids('potter', archived: true), [4]);
      expect(await ids('cafe zola'), [2]);
    });

    test('falls back to LIKE for short terms', () async {
      expect(await ids('pi'), [3]);
      expect(await ids('potter pi'), isEmpty);
    });

    test('a blank search keeps every row', () async {
      expect(await ids('  '), [1, 2, 3]);
      expect(bookSearch.matches('', rowid: db.books.id), const Constant(true));
    });

    test('works with a table alias', () async {
      final b = db.alias(db.books, 'b');
      final rows = await (db.select(
        b,
      )..where((t) => bookSearch.matches('rowling', rowid: t.id))).get();
      expect(rows.map((r) => r.id), [1]);
    });

    test('works with rowId and inside a join', () async {
      final query = db.select(db.books).join([])
        ..where(bookSearch.matches('martel', rowid: db.books.rowId));
      final rows = await query.get();
      expect(rows.map((r) => r.readTable(db.books).id), [3]);
    });

    test('combines with other expressions', () async {
      final query = db.select(db.books)
        ..where(
          (b) => bookSearch.matches('potter', rowid: b.id) | b.id.equals(3),
        )
        ..orderBy([(b) => OrderingTerm(expression: b.id)]);
      expect((await query.get()).map((b) => b.id), [1, 3, 4]);
    });

    test('binds hostile input as values', () async {
      for (final input in ['"', 'NEAR(a b)', "'; DROP TABLE books; --", '%']) {
        await ids(input);
      }
      expect(await db.select(db.books).get(), hasLength(4));
    });

    test('adds watched tables', () {
      final context = GenerationContext.fromDb(db);
      bookSearch
          .matches('potter', rowid: db.books.id, watchedTables: [db.booksFts])
          .writeInto(context);
      expect(context.watchedTables, contains(db.booksFts));
      expect(context.boundVariables, ['{"title" "author"} : ("potter")']);
    });

    test('has value equality', () {
      expect(
        bookSearch.matches('potter', rowid: db.books.id),
        bookSearch.matches('potter', rowid: db.books.id),
      );
      expect(
        bookSearch.matches('potter', rowid: db.books.id).hashCode,
        bookSearch.matches('potter', rowid: db.books.id).hashCode,
      );
      expect(
        bookSearch.matches('potter', rowid: db.books.id),
        isNot(bookSearch.matches('rowling', rowid: db.books.id)),
      );
    });

    test('re-runs a watched query when the content table changes', () async {
      final query = db.select(db.books)
        ..where((b) => bookSearch.matches('dune', rowid: b.id));
      final results = query.watch().map((rows) => rows.length);
      final expectation = expectLater(results, emitsInOrder([0, 1]));
      await pumpEventQueue();
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(title: 'Dune', author: 'Frank Herbert'),
          );
      await expectation;
    });
  });

  group('FtsClause', () {
    test('variables feed customSelect', () async {
      final clause = bookSearch.where('potter ro', rowid: 'b.id')!;
      final rows = await db
          .customSelect(
            'SELECT b.id FROM books b WHERE ${clause.sql}',
            variables: clause.variables,
            readsFrom: {db.books},
          )
          .get();
      expect(rows.map((r) => r.read<int>('id')), [1]);
    });

    test('toExpression embeds a raw clause in the query builder', () async {
      final clause = bookSearch.where('pi', rowid: 'books.id')!;
      final query = db.select(db.books)
        ..where((_) => clause.toExpression<bool>());
      expect((await query.get()).map((b) => b.id), [3]);
    });

    test('toExpression has value equality', () {
      final clause = bookSearch.condition('potter')!;
      expect(clause.toExpression<bool>(), clause.toExpression<bool>());
      expect(
        clause.toExpression<bool>().hashCode,
        clause.toExpression<bool>().hashCode,
      );
      expect(
        clause
            .toExpression<bool>(precedence: Precedence.comparisonEq)
            .precedence,
        Precedence.comparisonEq,
      );
    });
  });
}
