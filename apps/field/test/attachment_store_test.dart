import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncraft/data/attachment_store.dart';
import 'package:syncraft/data/database_schema.dart';
import 'package:syncraft/data/local_store.dart';

import 'replica_test.dart' show id;

void main() {
  test(
    'offline attachment bytes persist and invalid filenames are rejected',
    () async {
      sqfliteFfiInit();
      final local = LocalStore(
        await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: databaseOptions,
        ),
      );
      final store = AttachmentStore(local);
      final bytes = Uint8List.fromList([65, 66, 67]);
      final attachment = await store.add(
        id(100),
        'observation.txt',
        'text/plain',
        bytes,
      );
      expect(await store.bytes(attachment), bytes);
      expect((await store.list(id(100))).single['uploaded'], 0);
      await expectLater(
        store.add(id(100), '../file.txt', 'text/plain', bytes),
        throwsFormatException,
      );
      await expectLater(
        store.add(id(100), 'empty.txt', 'text/plain', Uint8List(0)),
        throwsFormatException,
      );
      expect(await store.list(id(101)), isEmpty);
      await local.close();
    },
  );
}
