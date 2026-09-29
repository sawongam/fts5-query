// An example prints what it finds.
// ignore_for_file: avoid_print

// Filters drift queries by a search box's text through an FTS5 index.
//
// Regenerate `drift_fts5_query_example.g.dart` with
// `dart run build_runner build`.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_fts5_query/drift_fts5_query.dart';

part 'drift_fts5_query_example.g.dart';

@DriftDatabase(include: {'books.drift'})
class LibraryDatabase extends _$LibraryDatabase {
  LibraryDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// Configure once per FTS5 table.
  static final bookSearch = FtsFilter(
    table: 'books_fts',
    columns: ['title', 'author'],
  );

  /// The query builder: a blank search lists every book.
  Future<List<Book>> searchBooks(String input) =>
      (select(books)
            ..where((b) => bookSearch.matches(input, rowid: b.id))
            ..orderBy([(b) => OrderingTerm(expression: b.title)]))
          .get();

  /// Hand-written SQL, for queries the builder cannot express.
  Future<List<String>> searchTitles(String input) {
    final clause = bookSearch.where(input, rowid: 'b.id');
    return customSelect(
      'SELECT b.title FROM books b'
      '${clause == null ? '' : ' WHERE ${clause.sql}'}'
      ' ORDER BY b.title',
      variables: clause?.variables ?? const [],
      readsFrom: {books},
    ).map((row) => row.read<String>('title')).get();
  }
}

Future<void> main() async {
  final db = LibraryDatabase(NativeDatabase.memory());
  await db.batch(
    (batch) => batch.insertAll(db.books, [
      BooksCompanion.insert(title: 'Harry Potter', author: 'J. K. Rowling'),
      BooksCompanion.insert(title: 'Life of Pi', author: 'Yann Martel'),
      BooksCompanion.insert(title: 'Thérèse Raquin', author: 'Émile Zola'),
    ]),
  );

  for (final input in ['potter rowling', 'pi', 'therese', '']) {
    final found = await db.searchBooks(input);
    print(
      '${input.isEmpty ? '(blank)' : input} → '
      '${found.map((b) => b.title).join('; ')}',
    );
  }
  print('zola → ${await db.searchTitles('zola')}');

  await db.close();
}
