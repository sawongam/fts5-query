// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_fts5_query_example.dart';

// ignore_for_file: type=lint
class Books extends Table with TableInfo<Books, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Books(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, author];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
    );
  }

  @override
  Books createAlias(String alias) {
    return Books(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String title;
  final String author;
  const Book({required this.id, required this.title, required this.author});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
    };
  }

  Book copyWith({int? id, String? title, String? author}) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author ?? this.author,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, author);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> author;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String author,
  }) : title = Value(title),
       author = Value(author);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? author,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? author,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author')
          ..write(')'))
        .toString();
  }
}

class BooksFts extends Table
    with TableInfo<BooksFts, BooksFt>, VirtualTableInfo<BooksFts, BooksFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BooksFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [title, author];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<BooksFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  BooksFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BooksFt(
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
    );
  }

  @override
  BooksFts createAlias(String alias) {
    return BooksFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(title, author, content = \'books\', content_rowid = \'id\', tokenize = \'trigram remove_diacritics 1\')';
}

class BooksFt extends DataClass implements Insertable<BooksFt> {
  final String title;
  final String author;
  const BooksFt({required this.title, required this.author});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    return map;
  }

  BooksFtsCompanion toCompanion(bool nullToAbsent) {
    return BooksFtsCompanion(title: Value(title), author: Value(author));
  }

  factory BooksFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BooksFt(
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
    };
  }

  BooksFt copyWith({String? title, String? author}) =>
      BooksFt(title: title ?? this.title, author: author ?? this.author);
  BooksFt copyWithCompanion(BooksFtsCompanion data) {
    return BooksFt(
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BooksFt(')
          ..write('title: $title, ')
          ..write('author: $author')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(title, author);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BooksFt &&
          other.title == this.title &&
          other.author == this.author);
}

class BooksFtsCompanion extends UpdateCompanion<BooksFt> {
  final Value<String> title;
  final Value<String> author;
  final Value<int> rowid;
  const BooksFtsCompanion({
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksFtsCompanion.insert({
    required String title,
    required String author,
    this.rowid = const Value.absent(),
  }) : title = Value(title),
       author = Value(author);
  static Insertable<BooksFt> custom({
    Expression<String>? title,
    Expression<String>? author,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksFtsCompanion copyWith({
    Value<String>? title,
    Value<String>? author,
    Value<int>? rowid,
  }) {
    return BooksFtsCompanion(
      title: title ?? this.title,
      author: author ?? this.author,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksFtsCompanion(')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDatabase extends GeneratedDatabase {
  _$LibraryDatabase(QueryExecutor e) : super(e);
  $LibraryDatabaseManager get managers => $LibraryDatabaseManager(this);
  late final Books books = Books(this);
  late final BooksFts booksFts = BooksFts(this);
  late final Trigger booksAi = Trigger(
    'CREATE TRIGGER books_ai AFTER INSERT ON books BEGIN INSERT INTO books_fts ("rowid", title, author) VALUES (new.id, new.title, new.author);END',
    'books_ai',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    booksFts,
    booksAi,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('books_fts', kind: UpdateKind.insert)],
    ),
  ]);
}

typedef $BooksCreateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      required String title,
      required String author,
    });
typedef $BooksUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> author,
    });

class $BooksFilterComposer extends Composer<_$LibraryDatabase, Books> {
  $BooksFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );
}

class $BooksOrderingComposer extends Composer<_$LibraryDatabase, Books> {
  $BooksOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );
}

class $BooksAnnotationComposer extends Composer<_$LibraryDatabase, Books> {
  $BooksAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);
}

class $BooksTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          Books,
          Book,
          $BooksFilterComposer,
          $BooksOrderingComposer,
          $BooksAnnotationComposer,
          $BooksCreateCompanionBuilder,
          $BooksUpdateCompanionBuilder,
          (Book, BaseReferences<_$LibraryDatabase, Books, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $BooksTableManager(_$LibraryDatabase db, Books table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BooksFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BooksOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BooksAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
              }) => BooksCompanion(id: id, title: title, author: author),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String author,
              }) => BooksCompanion.insert(id: id, title: title, author: author),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Books, Book>(table),
                  BaseReferences<_$LibraryDatabase, Books, Book>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $BooksProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      Books,
      Book,
      $BooksFilterComposer,
      $BooksOrderingComposer,
      $BooksAnnotationComposer,
      $BooksCreateCompanionBuilder,
      $BooksUpdateCompanionBuilder,
      (Book, BaseReferences<_$LibraryDatabase, Books, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $BooksFtsCreateCompanionBuilder =
    BooksFtsCompanion Function({
      required String title,
      required String author,
      Value<int> rowid,
    });
typedef $BooksFtsUpdateCompanionBuilder =
    BooksFtsCompanion Function({
      Value<String> title,
      Value<String> author,
      Value<int> rowid,
    });

class $BooksFtsFilterComposer extends Composer<_$LibraryDatabase, BooksFts> {
  $BooksFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );
}

class $BooksFtsOrderingComposer extends Composer<_$LibraryDatabase, BooksFts> {
  $BooksFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );
}

class $BooksFtsAnnotationComposer
    extends Composer<_$LibraryDatabase, BooksFts> {
  $BooksFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);
}

class $BooksFtsTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          BooksFts,
          BooksFt,
          $BooksFtsFilterComposer,
          $BooksFtsOrderingComposer,
          $BooksFtsAnnotationComposer,
          $BooksFtsCreateCompanionBuilder,
          $BooksFtsUpdateCompanionBuilder,
          (BooksFt, BaseReferences<_$LibraryDatabase, BooksFts, BooksFt>),
          BooksFt,
          PrefetchHooks Function()
        > {
  $BooksFtsTableManager(_$LibraryDatabase db, BooksFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BooksFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BooksFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BooksFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  BooksFtsCompanion(title: title, author: author, rowid: rowid),
          createCompanionCallback:
              ({
                required String title,
                required String author,
                Value<int> rowid = const Value.absent(),
              }) => BooksFtsCompanion.insert(
                title: title,
                author: author,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<BooksFts, BooksFt>(table),
                  BaseReferences<_$LibraryDatabase, BooksFts, BooksFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $BooksFtsProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      BooksFts,
      BooksFt,
      $BooksFtsFilterComposer,
      $BooksFtsOrderingComposer,
      $BooksFtsAnnotationComposer,
      $BooksFtsCreateCompanionBuilder,
      $BooksFtsUpdateCompanionBuilder,
      (BooksFt, BaseReferences<_$LibraryDatabase, BooksFts, BooksFt>),
      BooksFt,
      PrefetchHooks Function()
    >;

class $LibraryDatabaseManager {
  final _$LibraryDatabase _db;
  $LibraryDatabaseManager(this._db);
  $BooksTableManager get books => $BooksTableManager(_db, _db.books);
  $BooksFtsTableManager get booksFts =>
      $BooksFtsTableManager(_db, _db.booksFts);
}
