import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncraft/data/database_schema.dart';
import 'package:syncraft/data/local_store.dart';
import 'package:syncraft/domain/inspection.dart';
import 'package:syncraft/domain/workspace_controller.dart';
import 'package:syncraft/main.dart';
import 'package:syncraft/sync/api_client.dart';
import 'package:syncraft/sync/sync_engine.dart';
import 'package:syncraft/ui/conflict_panel.dart';

import 'replica_test.dart' show op, id;

void main() {
  testWidgets(
    'offline workspace renders at a narrow viewport without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late LocalStore store;
      await tester.runAsync(() async {
        sqfliteFfiInit();
        store = LocalStore(
          await databaseFactoryFfi.openDatabase(
            inMemoryDatabasePath,
            options: databaseOptions,
          ),
        );
      });
      final sync = SyncEngine(store, ApiClient('http://localhost:8091'));
      final c = WorkspaceController(store, sync);
      await tester.pumpWidget(SyncraftApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Working offline'), findsOneWidget);
      expect(find.byTooltip('New inspection'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('New inspection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a title'), findsOneWidget);
      expect(find.text('Enter a site'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      sync.dispose();
      await tester.runAsync(store.close);
    },
  );
  testWidgets('concurrent values remain separately visible', (tester) async {
    late LocalStore store;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      store = LocalStore(
        await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: databaseOptions,
        ),
      );
    });
    final sync = SyncEngine(store, ApiClient('http://localhost:8091'));
    final c = WorkspaceController(store, sync);
    final record = Inspection.project([
      op(1, 'North reading'),
      op(2, 'South reading'),
    ]).single;
    expect(record.id, id(100));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConflictPanel(record: record, controller: c),
        ),
      ),
    );
    expect(find.text('North reading'), findsOneWidget);
    expect(find.text('South reading'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    sync.dispose();
    await tester.runAsync(store.close);
  });
}
