import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncraft/data/database_schema.dart';
import 'package:syncraft/data/local_store.dart';
import 'package:syncraft/data/recovery.dart';
import 'replica_test.dart' show op;
void main(){test('recovery excludes credentials and requeues immutable operations',()async{
  sqfliteFfiInit();final a=LocalStore(await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,options:databaseOptions));
  await a.save([op(1,'field note')]);await a.setMetadata('token','should-not-export');final old=await a.deviceId();
  final bundle=await RecoveryBundle.export(a);expect(utf8.decode(bundle),isNot(contains('should-not-export')));
  await a.db.delete('outbox');await a.db.delete('operations');
  expect(await RecoveryBundle.restore(a,bundle),1);expect(await a.pendingCount(),1);expect(await a.deviceId(),isNot(old));
  await expectLater(RecoveryBundle.restore(a,bundle),throwsFormatException);await a.close();
});test('tampered envelope is rejected before mutation',()async{
  sqfliteFfiInit();final a=LocalStore(await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,options:databaseOptions));
  final bundle=await RecoveryBundle.export(a);final json=jsonDecode(utf8.decode(bundle)) as Map<String,dynamic>;json['sha256']='wrong';
  await expectLater(RecoveryBundle.restore(a,Uint8List.fromList(utf8.encode(jsonEncode(json)))),throwsFormatException);expect(await a.operations(),isEmpty);await a.close();
});}
