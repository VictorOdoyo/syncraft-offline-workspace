import 'package:crdt/map_crdt.dart';

import 'operation.dart';

/// Immutable operation keys are replicated by the CRDT; frontiers preserve field conflicts.
class Replica {
  final MapCrdt _crdt = MapCrdt(['operations']);
  final Map<String, Operation> _operations = {};
  List<Operation> get operations => List.unmodifiable(_operations.values);
  Future<void> addAll(Iterable<Operation> incoming) async {
    final staged = Map<String, Operation>.from(_operations);
    final additions = <String, dynamic>{};
    for (final op in incoming) {
      final existing = staged[op.id];
      if (existing != null) {
        if (!existing.equivalent(op)) {
          throw const FormatException('Immutable operation ID collision');
        }
        continue;
      }
      for (final parent in op.parents) {
        final previous = staged[parent];
        if (previous == null ||
            previous.record != op.record ||
            previous.field != op.field) {
          throw const FormatException('Missing or invalid causal parent');
        }
      }
      staged[op.id] = op;
      additions[op.id] = op.toJson();
    }
    if (additions.isNotEmpty) {
      await _crdt.putAll({'operations': additions});
    }
    _operations
      ..clear()
      ..addAll(staged);
  }

  Future<void> merge(Replica remote) async {
    // Validate IDs and parent references before invoking the package merge.
    await addAll(remote.operations);
    await _crdt.merge(remote._crdt.getChangeset());
  }
}
