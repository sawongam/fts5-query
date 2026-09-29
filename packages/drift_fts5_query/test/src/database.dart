import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

@DriftDatabase(include: {'books.drift'})
class TestDatabase extends _$TestDatabase {
  TestDatabase() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
