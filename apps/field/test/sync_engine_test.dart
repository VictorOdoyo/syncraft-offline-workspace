import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncraft/data/database_schema.dart';
import 'package:syncraft/data/local_store.dart';
import 'package:syncraft/sync/api_client.dart';
import 'package:syncraft/sync/sync_engine.dart';

import 'replica_test.dart' show op;

void main() {
  test(
    'failed push retains outbox and retry acknowledges only committed work',
    () async {
      sqfliteFfiInit();
      final local = LocalStore(
        await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: databaseOptions,
        ),
      );
      await local.save([op(1, 'offline')]);
      var fail = true;
      final api = ApiClient(
        'http://localhost:8091',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/push')) {
            return http.Response(
              fail ? '{"error":"unavailable"}' : '{"cursor":99}',
              fail ? 503 : 200,
            );
          }
          return http.Response(
            jsonEncode({'entries': [], 'cursor': 0, 'more': false}),
            200,
          );
        }),
      );
      final engine = SyncEngine(local, api)..connected = true;
      await engine.synchronize();
      expect(await local.pendingCount(), 1);
      expect(engine.error, isNotNull);
      fail = false;
      await engine.synchronize();
      expect(await local.pendingCount(), 0);
      expect(await local.cursor(), 0);
      expect(engine.error, isNull);
      engine.dispose();
      await local.close();
    },
  );
  test('remote plaintext endpoints are rejected', () {
    expect(() => ApiClient('http://remote.example'), throwsFormatException);
  });
  for (final status in [401, 403]) {
    test(
      'authorization failure $status disconnects without losing edits',
      () async {
        sqfliteFfiInit();
        final local = LocalStore(
          await databaseFactoryFfi.openDatabase(
            inMemoryDatabasePath,
            options: databaseOptions,
          ),
        );
        await local.save([op(1, 'unsent inspection')]);
        var requests = 0;
        final api = ApiClient(
          'http://localhost:8091',
          client: MockClient((_) async {
            requests++;
            return http.Response('{"error":"access denied"}', status);
          }),
        )..token = 'expired-or-revoked';
        final engine = SyncEngine(local, api)..connected = true;
        try {
          engine.setPaused(true);
          await engine.synchronize();
          expect(requests, 0);
          engine.paused = false;
          await engine.synchronize();
          expect(engine.connected, isFalse);
          expect(api.token, isNull);
          expect(await local.pendingCount(), 1);
          expect(await local.cursor(), 0);
          await engine.synchronize();
          expect(requests, 1);
        } finally {
          engine.dispose();
          await local.close();
        }
      },
    );
  }
  test(
    'account binding rejects another identity before network access',
    () async {
      sqfliteFfiInit();
      final local = LocalStore(
        await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: databaseOptions,
        ),
      );
      await local.setMetadata('account', 'http://localhost:8091|inspector');
      var requests = 0;
      final api = ApiClient(
        'http://localhost:8091',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      final engine = SyncEngine(local, api);
      try {
        await expectLater(
          engine.login('reviewer', 'local-demo'),
          throwsFormatException,
        );
        expect(requests, 0);
        expect(engine.connected, isFalse);
        expect(api.token, isNull);
      } finally {
        engine.dispose();
        await local.close();
      }
    },
  );
}
