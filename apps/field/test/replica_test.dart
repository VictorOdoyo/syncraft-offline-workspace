import 'package:flutter_test/flutter_test.dart';
import 'package:syncraft/domain/operation.dart';
import 'package:syncraft/domain/inspection.dart';
import 'package:syncraft/domain/replica.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Operation op(int n, String value, [List<String> parents = const []]) =>
    Operation(
      id: id(n),
      record: id(100),
      field: 'notes',
      value: value,
      parents: parents,
    );
void main() {
  test('two replicas converge without dropping a concurrent value', () async {
    final a = Replica(), b = Replica();
    await a.addAll([op(1, 'north')]);
    await b.addAll([op(2, 'south')]);
    await a.merge(b);
    await b.merge(a);
    expect(frontier(a.operations, id(100), 'notes').map((o) => o.value), [
      'north',
      'south',
    ]);
    expect(frontier(b.operations, id(100), 'notes').map((o) => o.value), [
      'north',
      'south',
    ]);
    await a.addAll([
      op(3, 'both', [id(1), id(2)]),
    ]);
    await b.merge(a);
    expect(frontier(b.operations, id(100), 'notes').single.value, 'both');
  });
  test('invalid batch is atomic and identical replay is harmless', () async {
    final replica = Replica();
    await replica.addAll([op(1, 'a')]);
    await expectLater(
      replica.addAll([
        op(2, 'b'),
        op(3, 'bad', [id(99)]),
      ]),
      throwsFormatException,
    );
    expect(replica.operations.length, 1);
    await replica.addAll([op(1, 'a')]);
    expect(replica.operations.length, 1);
    await expectLater(
      replica.addAll([op(1, 'changed')]),
      throwsFormatException,
    );
  });
  test('archive conflicts remain conservatively archived', () {
    final operations = [
      Operation(
        id: id(1),
        record: id(100),
        field: 'archived',
        value: 'true',
        parents: [],
      ),
      Operation(
        id: id(2),
        record: id(100),
        field: 'archived',
        value: 'false',
        parents: [],
      ),
    ];
    final record = Inspection.project(operations).single;
    expect(record.archived, isTrue);
    expect(record.conflicts, ['archived']);
  });
}
