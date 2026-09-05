import 'package:sqflite_common/sqlite_api.dart';

final databaseOptions = OpenDatabaseOptions(
  version: 1,
  onConfigure: (db) async {
    await db.execute('PRAGMA foreign_keys=ON');
  },
  onCreate: (db, version) async {
    await db.execute(
      'CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE operations(position INTEGER PRIMARY KEY AUTOINCREMENT,id TEXT UNIQUE NOT NULL,content TEXT NOT NULL,actor TEXT NOT NULL DEFAULT \'local\',created TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE outbox(id TEXT PRIMARY KEY REFERENCES operations(id),attempts INTEGER NOT NULL DEFAULT 0,error TEXT)',
    );
    await db.execute(
      'CREATE TABLE attachments(id TEXT PRIMARY KEY,record TEXT NOT NULL,name TEXT NOT NULL,media_type TEXT NOT NULL,sha256 TEXT NOT NULL,content BLOB NOT NULL,uploaded INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute('CREATE INDEX attachments_record ON attachments(record)');
  },
);
