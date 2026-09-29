import 'package:fts5_query/fts5_query.dart';
import 'package:test/test.dart';

/// The exact SQL each configuration produces. Behaviour against a real
/// database is covered by `sqlite_test.dart`.
void main() {
  final books = FtsFilter(table: 'books_fts', columns: ['title', 'author']);
  const cols = '{"title" "author"} : ';
  const like = "title LIKE ? ESCAPE '\\' OR author LIKE ? ESCAPE '\\'";

  group('construction', () {
    test('accepts bare, quoted and qualified identifiers', () {
      expect(
        () => FtsFilter(table: 'main.books_fts', columns: ['title']),
        returnsNormally,
      );
      expect(
        () => FtsFilter(table: '"search index"', columns: ['"the title"']),
        returnsNormally,
      );
      expect(
        () => FtsFilter(table: 'bücher', columns: ['titel']),
        returnsNormally,
      );
    });

    for (final table in [
      '',
      'books; DROP TABLE books',
      'books_fts WHERE 1',
      '1books',
      '[books]',
      '`books`',
      'a.b.c',
      '"unterminated',
    ]) {
      test('rejects the table name ${_show(table)}', () {
        expect(
          () => FtsFilter(table: table, columns: ['title']),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'table')),
        );
      });
    }

    test('rejects a qualified or malformed column', () {
      for (final column in ['t.title', 'title)', "title' OR '1", '']) {
        expect(
          () => FtsFilter(table: 'books_fts', columns: [column]),
          throwsA(
            isA<ArgumentError>().having((e) => e.name, 'name', 'columns'),
          ),
          reason: column,
        );
      }
    });

    test('rejects no columns and a maxTerms below one', () {
      expect(
        () => FtsFilter(table: 'books_fts', columns: const []),
        throwsArgumentError,
      );
      expect(
        () => FtsFilter(table: 'books_fts', columns: ['title'], maxTerms: 0),
        throwsArgumentError,
      );
    });

    test('rejects a malformed rowid', () {
      expect(
        () => books.where('potter', rowid: 'b.rowid OR 1=1'),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'rowid')),
      );
      expect(
        () => books.where('potter', rowid: 'main.b.rowid'),
        returnsNormally,
      );
    });

    test('the columns cannot be changed afterwards', () {
      expect(() => books.columns.add('x'), throwsUnsupportedError);
    });
  });

  group('blank search', () {
    test('produces no clause', () {
      for (final search in ['', '   ', '""', '\u0000']) {
        expect(books.condition(search), isNull);
        expect(books.subquery(search), isNull);
        expect(books.where(search, rowid: 'b.rowid'), isNull);
      }
    });
  });

  group('trigram', () {
    test('sends long terms through MATCH as quoted phrases', () {
      final clause = books.condition('harry potter')!;
      expect(clause.sql, 'books_fts MATCH ?');
      expect(clause.arguments, ['$cols("harry" AND "potter")']);
      expect(clause.canRank, isTrue);
    });

    test('searches short terms with LIKE over every column', () {
      final clause = books.condition('pi')!;
      expect(clause.sql, '($like)');
      expect(clause.arguments, ['%pi%', '%pi%']);
      expect(clause.canRank, isFalse);
    });

    test('ANDs the index and the scans together, in parentheses', () {
      final clause = books.condition('potter JK')!;
      expect(clause.sql, '(books_fts MATCH ? AND ($like))');
      expect(clause.arguments, ['$cols("potter")', '%JK%', '%JK%']);
      expect(clause.canRank, isTrue);
    });

    test('counts code points, so an emoji pair is short', () {
      final clause = books.condition('😀😀 नेपाल')!;
      expect(clause.arguments.first, '$cols("नेपाल")');
      expect(clause.arguments.skip(1), ['%😀😀%', '%😀😀%']);
    });

    test('binds FTS5 operators as text', () {
      final clause = books.condition('NEAR(abc) OR* col:x ^start')!;
      expect(clause.arguments, [
        '$cols("NEAR(abc)" AND "OR*" AND "col:x" AND "^start")',
      ]);
    });

    test('doubles quotes when they are not phrase delimiters', () {
      final filter = FtsFilter(
        table: 'books_fts',
        columns: ['title'],
        quotedPhrases: false,
      );
      expect(filter.condition('say"hi"')!.arguments, [
        '{"title"} : ("say""hi""")',
      ]);
    });

    test('escapes LIKE wildcards in short terms', () {
      final clause = books.condition(r'% _\')!;
      expect(clause.arguments, [r'%\%%', r'%\%%', r'%\_\\%', r'%\_\\%']);
    });

    test('minLength moves the index threshold', () {
      final filter = FtsFilter(
        table: 'books_fts',
        columns: ['title'],
        tokenizer: const FtsTokenizer.trigram(minLength: 4),
      );
      final clause = filter.condition('abc abcd')!;
      expect(clause.arguments, ['{"title"} : ("abcd")', '%abc%']);
    });

    test('case-sensitive tables scan with GLOB', () {
      final filter = FtsFilter(
        table: 'books_fts',
        columns: ['title', 'author'],
        tokenizer: const FtsTokenizer.trigram(caseSensitive: true),
      );
      final clause = filter.condition('P*')!;
      expect(clause.sql, '(title GLOB ? OR author GLOB ?)');
      expect(clause.arguments, ['*P[*]*', '*P[*]*']);
    });
  });

  group('words', () {
    FtsFilter words(FtsPrefix prefix) => FtsFilter(
      table: 'books_fts',
      columns: ['title', 'author'],
      tokenizer: FtsTokenizer.words(prefix: prefix),
    );

    test('sends every term, however short, through MATCH', () {
      final clause = words(FtsPrefix.none).condition('a harry')!;
      expect(clause.sql, 'books_fts MATCH ?');
      expect(clause.arguments, ['$cols("a" AND "harry")']);
      expect(clause.canRank, isTrue);
    });

    test('prefix last matches only the last term by prefix', () {
      expect(words(FtsPrefix.last).condition('harry pot')!.arguments, [
        '$cols("harry" AND "pot"*)',
      ]);
    });

    test('prefix all matches every term by prefix', () {
      expect(words(FtsPrefix.all).condition('har pot')!.arguments, [
        '$cols("har"* AND "pot"*)',
      ]);
    });

    test('never adds a prefix to a quoted phrase', () {
      expect(words(FtsPrefix.all).condition('"harry potter"')!.arguments, [
        '$cols("harry potter")',
      ]);
    });
  });

  group('combine any', () {
    final anyBooks = FtsFilter(
      table: 'books_fts',
      columns: ['title', 'author'],
      combine: FtsCombine.any,
    );

    test('ORs the phrases inside MATCH', () {
      final clause = anyBooks.condition('harry zola')!;
      expect(clause.sql, 'books_fts MATCH ?');
      expect(clause.arguments, ['$cols("harry" OR "zola")']);
      expect(clause.canRank, isTrue);
    });

    test('moves MATCH into a subquery beside a scan', () {
      final clause = anyBooks.condition('harry pi')!;
      expect(
        clause.sql,
        '(rowid IN (SELECT rowid FROM books_fts WHERE books_fts MATCH ?) '
        'OR ($like))',
      );
      expect(clause.canRank, isFalse);
    });
  });

  group('wrappers', () {
    test('subquery selects the rowids', () {
      expect(
        books.subquery('potter')!.sql,
        'SELECT rowid FROM books_fts WHERE books_fts MATCH ?',
      );
    });

    test('where tests the outer rowid against the subquery', () {
      final clause = books.where('potter pi', rowid: 'b.rowid')!;
      expect(
        clause.sql,
        'b.rowid IN (SELECT rowid FROM books_fts WHERE '
        '(books_fts MATCH ? AND ($like)))',
      );
      expect(clause.arguments, ['$cols("potter")', '%pi%', '%pi%']);
    });

    test('a qualified table matches on its own name', () {
      final filter = FtsFilter(table: 'main.books_fts', columns: ['title']);
      expect(
        filter.subquery('potter')!.sql,
        'SELECT rowid FROM main.books_fts WHERE books_fts MATCH ?',
      );
    });

    test('quoted identifiers are written as given and unquoted in MATCH', () {
      final filter = FtsFilter(
        table: '"search index"',
        columns: ['"the ""title"""'],
      );
      final clause = filter.condition('potter pi')!;
      expect(
        clause.sql,
        '("search index" MATCH ? AND '
        '("the ""title""" LIKE ? ESCAPE \'\\\'))',
      );
      expect(clause.arguments.first, '{"the ""title"""} : ("potter")');
    });
  });

  group('FtsClause', () {
    final clause = books.condition('potter pi')!;

    test('render numbers the placeholders', () {
      expect(
        clause.render((i) => '?${i + 1}'),
        "(books_fts MATCH ?1 AND (title LIKE ?2 ESCAPE '\\' OR "
        "author LIKE ?3 ESCAPE '\\'))",
      );
    });

    test(
      'writeTo alternates SQL and arguments, starting and ending on SQL',
      () {
        final events = <String>[];
        clause.writeTo(
          sql: (s) => events.add('sql:$s'),
          argument: (a) => events.add('arg:$a'),
        );
        expect(events.first, startsWith('sql:'));
        expect(events.last, startsWith('sql:'));
        expect(events.where((e) => e.startsWith('arg:')), hasLength(3));
      },
    );

    test('has value equality', () {
      expect(books.condition('potter pi'), clause);
      expect(books.condition('potter pi').hashCode, clause.hashCode);
      expect(books.condition('potter'), isNot(clause));
    });

    test('toString shows the SQL and the arguments', () {
      expect(
        books.condition('potter').toString(),
        contains('books_fts MATCH ?'),
      );
    });

    test('arguments cannot be changed', () {
      expect(() => clause.arguments.add('x'), throwsUnsupportedError);
    });
  });

  test('terms reports what the filter searches for', () {
    final filter = FtsFilter(
      table: 'books_fts',
      columns: ['title'],
      quotedPhrases: false,
      maxTerms: 2,
    );
    expect(filter.terms('"a b" c'), [
      const SearchTerm('"a'),
      const SearchTerm('b"'),
    ]);
  });

  test('tokenizers have value equality and readable toString', () {
    expect(const FtsTokenizer.trigram(), const TrigramTokenizer());
    expect(const FtsTokenizer.words(), const WordTokenizer());
    expect(
      const FtsTokenizer.words(prefix: FtsPrefix.none),
      isNot(const FtsTokenizer.words()),
    );
    expect(
      const FtsTokenizer.trigram().hashCode,
      const TrigramTokenizer().hashCode,
    );
    expect(books.toString(), contains('books_fts'));
    expect(const FtsTokenizer.words().toString(), contains('last'));
  });
}

String _show(String value) => value.isEmpty ? '(empty)' : '`$value`';
