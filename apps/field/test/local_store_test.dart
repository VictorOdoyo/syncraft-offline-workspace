import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncraft/data/database_schema.dart';
import 'package:syncraft/data/local_store.dart';

import 'replica_test.dart' show op, id;

void main() {
  late LocalStore store;
  setUp(() async {
    sqfliteFfiInit();
    store = LocalStore(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: databaseOptions,
      ),
    );
  });
  tearDown(() async {
    await store.close();
  });
  test(
    'editing creates durable outbox and replay creates no duplicate',
    () async {
      await store.save([op(1, 'first')]);
      await store.save([op(1, 'first')]);
      expect(await store.pendingCount(), 1);
      expect((await store.operations()).length, 1);
      await store.acknowledge([id(1)]);
      expect(await store.pendingCount(), 0);
      expect((await store.operations()).length, 1);
    },
  );
  test('failed batch does not partially save', () async {
    await expectLater(
      store.save([
        op(1, 'ok'),
        op(2, 'bad', [id(999)]),
      ]),
      throwsFormatException,
    );
    expect(await store.pendingCount(), 0);
    expect(await store.operations(), isEmpty);
  });
  test('page data and cursor roll back together on a gap', () async {
    final entry = {
      'sequence': 2,
      'actor': 'inspector',
      'created': '2026-09-05T00:00:00Z',
      'operation': op(1, 'downloaded').toJson(),
    };
    await expectLater(
      store.applyPage({
        'entries': [entry],
        'cursor': 2,
      }),
      throwsFormatException,
    );
    expect(await store.cursor(), 0);
    expect(await store.operations(), isEmpty);
    entry['sequence'] = 1;
    await store.applyPage({
      'entries': [entry],
      'cursor': 1,
    });
    expect(await store.cursor(), 1);
    expect((await store.operations()).single.value, 'downloaded');
  });
  test('device identity stays stable', () async {
    expect(await store.deviceId(), await store.deviceId());
  });
}
