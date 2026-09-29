# fts5_query

Turn what a user types into a search box into a safe SQLite FTS5 filter.

| Package | | |
| --- | --- | --- |
| [`fts5_query`](packages/fts5_query) | [![pub](https://img.shields.io/pub/v/fts5_query.svg)](https://pub.dev/packages/fts5_query) | Pure Dart, no dependencies. For `sqlite3`, `sqflite`, or any SQL string |
| [`drift_fts5_query`](packages/drift_fts5_query) | [![pub](https://img.shields.io/pub/v/drift_fts5_query.svg)](https://pub.dev/packages/drift_fts5_query) | Typed drift `Expression`s and `Variable`s |

## Development

A [pub workspace](https://dart.dev/tools/pub/workspaces); Dart 3.8 or later.

```sh
dart pub get
(cd packages/drift_fts5_query && dart run build_runner build)  # test database
dart format packages
dart analyze --fatal-infos packages
(cd packages/fts5_query && dart test)
(cd packages/drift_fts5_query && dart test)
```

The tests run against a real SQLite with FTS5, which the `sqlite3` package
builds for them.

## Releasing

1. Bump `version:` and add a `CHANGELOG.md` entry in the package.
2. Merge, then push a tag: `fts5_query-v1.2.3` or `drift_fts5_query-v1.2.3`.
3. `.github/workflows/publish.yaml` publishes it through pub.dev's automated
   publishing. Enable that once per package on pub.dev's admin page.

When `fts5_query` gains an API that `drift_fts5_query` uses, release
`fts5_query` first and raise the lower bound in `drift_fts5_query`.

## License

MIT
