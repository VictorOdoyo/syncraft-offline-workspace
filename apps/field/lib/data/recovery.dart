import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../domain/operation.dart';
import '../domain/replica.dart';
import 'local_store.dart';

class RecoveryBundle {
  static const maxBytes=50*1024*1024;
  static Future<Uint8List> export(LocalStore store)async{
    final rows=await store.db.query('attachments');
    final payload={'operations':(await store.operations()).map((o)=>o.toJson()).toList(),
      'attachments':rows.map((r)=>{...r,'content':base64Encode(r['content'] as Uint8List)}).toList()};
    final content=jsonEncode(payload);final bytes=Uint8List.fromList(utf8.encode(jsonEncode({'version':1,'sha256':sha256.convert(utf8.encode(content)).toString(),'payload':content})));
    if(bytes.length>maxBytes){throw const FormatException('Recovery bundle exceeds 50 MiB');}return bytes;
  }
  static Future<int> restore(LocalStore store,Uint8List bytes)async{
    if(bytes.length>maxBytes){throw const FormatException('Recovery bundle exceeds 50 MiB');}
    if((await store.operations()).isNotEmpty){throw const FormatException('Restore requires an empty local workspace');}
    final envelope=jsonDecode(utf8.decode(bytes)) as Map<String,dynamic>;
    if(envelope['version']!=1||envelope['payload'] is! String){throw const FormatException('Unsupported recovery format');}
    final content=envelope['payload'] as String;if(sha256.convert(utf8.encode(content)).toString()!=envelope['sha256']){throw const FormatException('Recovery checksum mismatch');}
    final payload=jsonDecode(content) as Map<String,dynamic>;final rawOps=payload['operations'] as List;
    if(rawOps.length>10000){throw const FormatException('Too many operations');}
    final ops=rawOps.map((o)=>Operation.fromJson(Map<String,dynamic>.from(o as Map))).toList();
    final replica=Replica();await replica.addAll(ops);
    final attachments=<Map<String,Object?>>[];
    for(final raw in payload['attachments'] as List){final row=Map<String,dynamic>.from(raw as Map);final data=base64Decode(row['content'] as String);
      if(!idPattern.hasMatch(row['id'] as String)||!idPattern.hasMatch(row['record'] as String)||data.isEmpty||data.length>5*1024*1024||sha256.convert(data).toString()!=row['sha256']||!['image/jpeg','image/png','application/pdf','text/plain'].contains(row['media_type'])){throw const FormatException('Invalid recovery attachment');}
      final name=row['name'] as String;if(name.isEmpty||name.length>200||name.contains(RegExp(r'[/\\\r\n]'))){throw const FormatException('Invalid attachment filename');}
      attachments.add({'id':row['id'],'record':row['record'],'name':name,'media_type':row['media_type'],'sha256':row['sha256'],'content':data,'uploaded':0});
    }
    await store.db.transaction((tx)async{
      if((await tx.query('operations',limit:1)).isNotEmpty){throw const FormatException('Workspace changed during restore');}
      for(final op in ops){await tx.insert('operations',{'id':op.id,'content':jsonEncode(op.toJson()),'created':DateTime.now().toUtc().toIso8601String()});await tx.insert('outbox',{'id':op.id});}
      for(final row in attachments){await tx.insert('attachments',row);}
      await tx.delete('metadata',where:'key IN (?,?)',whereArgs:['device','cursor']);
    });
    await store.deviceId();return ops.length;
  }
}
