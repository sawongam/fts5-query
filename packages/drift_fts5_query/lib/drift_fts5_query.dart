/// [drift](https://pub.dev/packages/drift) integration for `fts5_query`:
/// filter any drift query by what a user typed into a search box.
///
/// Re-exports `package:fts5_query/fts5_query.dart`, so this one import is
/// all a drift app needs.
library;

export 'package:fts5_query/fts5_query.dart';

export 'src/drift_extensions.dart';
