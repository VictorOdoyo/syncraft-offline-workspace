import '../domain/operation.dart';
import 'local_store.dart';

Future<void> loadDemo(LocalStore store) async {
  if ((await store.operations()).isNotEmpty) {
    return;
  }
  final records = [
    [
      'Pump station inspection',
      'North waterworks',
      'in_progress',
      'high',
      'Pressure gauge fluctuates during startup. Photograph seal and confirm isolation.',
    ],
    [
      'Emergency access review',
      'Riverside depot',
      'draft',
      'critical',
      'Confirm the east service gate is accessible before the evening delivery.',
    ],
    [
      'Cold room handover',
      'Harbor stores',
      'complete',
      'normal',
      'Temperature remained stable through the observation window.',
    ],
    [
      'Roof drainage survey',
      'Central library',
      'in_progress',
      'normal',
      'Inspect debris around the south outlet after rain.',
    ],
  ];
  var sequence = 1;
  final operations = <Operation>[];
  for (var i = 0; i < records.length; i++) {
    final record =
        '10000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}';
    for (var f = 0; f < 5; f++) {
      operations.add(
        Operation(
          id: '20000000-0000-4000-8000-${(sequence++).toString().padLeft(12, '0')}',
          record: record,
          field: ['title', 'site', 'status', 'priority', 'notes'][f],
          value: records[i][f],
          parents: [],
        ),
      );
    }
    for (final field in ['check.safety', 'check.equipment', 'check.access']) {
      operations.add(
        Operation(
          id: '20000000-0000-4000-8000-${(sequence++).toString().padLeft(12, '0')}',
          record: record,
          field: field,
          value: i == 2 ? 'true' : 'false',
          parents: [],
        ),
      );
    }
  }
  await store.save(operations);
}
