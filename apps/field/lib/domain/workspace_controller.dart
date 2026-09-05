import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/local_store.dart';
import '../sync/sync_engine.dart';
import 'inspection.dart';
import 'operation.dart';

class WorkspaceController extends ChangeNotifier {
  final LocalStore store;
  final SyncEngine sync;
  List<Operation> operations = [];
  List<Inspection> inspections = [];
  int pending = 0;
  String query = '', status = 'all', priority = 'all';
  bool showArchived = false, conflictsOnly = false;
  String? selectedId;
  bool _disposed = false;
  int _generation = 0;
  WorkspaceController(this.store, this.sync) {
    sync.addListener(_onSync);
  }
  void _onSync() {
    if (!sync.busy) {
      unawaited(refresh());
    } else {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final result = await store.operations();
    final count = await store.pendingCount();
    if (_disposed || generation != _generation) {
      return;
    }
    operations = result;
    inspections = Inspection.project(result);
    pending = count;
    notifyListeners();
  }

  List<Inspection> get filtered => inspections
      .where(
        (r) =>
            r.archived == showArchived &&
            (status == 'all' || r.status == status) &&
            (priority == 'all' || r.priority == priority) &&
            (!conflictsOnly || r.conflicts.isNotEmpty) &&
            '${r.title} ${r.site} ${r.value('notes')}'.toLowerCase().contains(
              query.trim().toLowerCase(),
            ),
      )
      .toList();
  Inspection? get selected =>
      inspections.where((r) => r.id == selectedId).firstOrNull;
  void filter({
    String? text,
    String? state,
    String? urgency,
    bool? archived,
    bool? conflicts,
  }) {
    query = text ?? query;
    status = state ?? status;
    priority = urgency ?? priority;
    showArchived = archived ?? showArchived;
    conflictsOnly = conflicts ?? conflictsOnly;
    notifyListeners();
  }

  void clearFilters() {
    query = '';
    status = 'all';
    priority = 'all';
    showArchived = false;
    conflictsOnly = false;
    notifyListeners();
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  Future<String> create(String title, String site) async {
    final id = const Uuid().v4();
    await store.save([
      for (final entry in {
        'title': title.trim(),
        'site': site.trim(),
        'status': 'draft',
        'priority': 'normal',
      }.entries)
        Operation(
          id: const Uuid().v4(),
          record: id,
          field: entry.key,
          value: entry.value,
          parents: [],
        ),
    ]);
    await refresh();
    select(id);
    unawaited(sync.synchronize());
    return id;
  }

  Future<void> edit(
    String record,
    String field,
    String value,
    List<String> observed,
  ) async {
    await store.save([
      Operation(
        id: const Uuid().v4(),
        record: record,
        field: field,
        value: value,
        parents: observed,
      ),
    ]);
    await refresh();
    unawaited(sync.synchronize());
  }

  Future<void> archive(Inspection record, bool value) => edit(
    record.id,
    'archived',
    '$value',
    record.fields['archived']!.map((o) => o.id).toList(),
  );
  @override
  void dispose() {
    _disposed = true;
    sync.removeListener(_onSync);
    super.dispose();
  }
}
