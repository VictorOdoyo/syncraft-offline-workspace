import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';
import '../domain/operation.dart';
import '../domain/replica.dart';
import 'database_schema.dart';
import 'open_database.dart';

class LocalStore {
  final Database db;
  LocalStore(this.db);
  static Future<LocalStore> open() async => LocalStore(await openLocalDatabase('syncraft-v1.db',databaseOptions));
  Future<String?> metadata(String key) async => (await db.query('metadata',where:'key=?',whereArgs:[key])).firstOrNull?['value'] as String?;
  Future<void> setMetadata(String key,String value) => db.insert('metadata',{'key':key,'value':value},conflictAlgorithm:ConflictAlgorithm.replace).then((_){});
  Future<String> deviceId() async {
    return db.transaction((tx) async {
      final rows=await tx.query('metadata',where:'key=?',whereArgs:['device']);
      if(rows.isNotEmpty) { return rows.first['value'] as String; }
      final id=const Uuid().v4();await tx.insert('metadata',{'key':'device','value':id});return id;
    });
  }
  Future<List<Operation>> operations([DatabaseExecutor? executor]) async =>
    (await (executor??db).query('operations',orderBy:'position')).map((r)=>Operation.fromJson(jsonDecode(r['content'] as String) as Map<String,dynamic>)).toList();
  Future<void> save(List<Operation> batch) async {
    await db.transaction((tx) async {
      final replica=Replica();await replica.addAll(await operations(tx));await replica.addAll(batch);
      for(final op in batch) {
        final found=await tx.query('operations',columns:['id'],where:'id=?',whereArgs:[op.id]);
        if(found.isNotEmpty) { continue; }
        await tx.insert('operations',{'id':op.id,'content':jsonEncode(op.toJson()),'created':DateTime.now().toUtc().toIso8601String()});
        await tx.insert('outbox',{'id':op.id});
      }
    });
  }
  Future<List<Operation>> pending() async => (await db.rawQuery('SELECT o.content FROM operations o JOIN outbox q ON q.id=o.id ORDER BY o.position LIMIT 100')).map((r)=>Operation.fromJson(jsonDecode(r['content'] as String) as Map<String,dynamic>)).toList();
  Future<int> pendingCount() async => (await db.rawQuery('SELECT count(*) AS n FROM outbox')).first['n'] as int;
  Future<void> acknowledge(List<String> ids) async { await db.transaction((tx) async {for(final id in ids) {await tx.delete('outbox',where:'id=?',whereArgs:[id]);}}); }
  Future<void> failed(List<String> ids,String error) async {await db.transaction((tx) async {for(final id in ids) {await tx.rawUpdate('UPDATE outbox SET attempts=attempts+1,error=? WHERE id=?',[error.length>500?error.substring(0,500):error,id]);}});}
  Future<int> cursor() async => int.parse(await metadata('cursor')??'0');
  Future<void> applyPage(Map<String,dynamic> page) async {
    final entries=List<Map<String,dynamic>>.from(page['entries'] as List);
    final next=page['cursor'] as int;
    await db.transaction((tx) async {
      final previousRows=await tx.query('metadata',where:'key=?',whereArgs:['cursor']);
      final previous=int.parse(previousRows.firstOrNull?['value'] as String? ?? '0');
      if(next<previous || (entries.isEmpty && next!=previous)) {throw const FormatException('Invalid sync cursor');}
      var expected=previous;
      for(final entry in entries) {if(entry['sequence']!=++expected) {throw const FormatException('Noncontiguous sync page');}}
      if(expected!=next) {throw const FormatException('Page cursor mismatch');}
      final incoming=entries.map((e)=>Operation.fromJson(e['operation'] as Map<String,dynamic>)).toList();
      final replica=Replica();await replica.addAll(await operations(tx));await replica.addAll(incoming);
      for(var i=0;i<incoming.length;i++) {
        final op=incoming[i];final entry=entries[i];
        await tx.insert('operations',{'id':op.id,'content':jsonEncode(op.toJson()),'actor':entry['actor'],'created':entry['created']},conflictAlgorithm:ConflictAlgorithm.ignore);
        await tx.update('operations',{'actor':entry['actor'],'created':entry['created']},where:'id=?',whereArgs:[op.id]);
      }
      await tx.insert('metadata',{'key':'cursor','value':'$next'},conflictAlgorithm:ConflictAlgorithm.replace);
    });
  }
  Future<void> close()=>db.close();
}
