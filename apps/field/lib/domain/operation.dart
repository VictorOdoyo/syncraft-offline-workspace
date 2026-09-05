import 'dart:convert';

const fieldLimits = {
  'title': 200,
  'site': 200,
  'notes': 16000,
  'status': 20,
  'priority': 20,
  'archived': 5,
  'check.safety': 5,
  'check.equipment': 5,
  'check.access': 5,
};
final idPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

class Operation {
  final String id, record, field, value;
  final List<String> parents;
  Operation({
    required this.id,
    required this.record,
    required this.field,
    required this.value,
    required List<String> parents,
  }) : parents = List.unmodifiable(parents) {
    final limit = fieldLimits[field];
    if (!idPattern.hasMatch(id) ||
        !idPattern.hasMatch(record) ||
        limit == null ||
        utf8.encode(value).length > limit ||
        parents.length > 100 ||
        parents.toSet().length != parents.length ||
        parents.any((p) => !idPattern.hasMatch(p) || p == id)) {
      throw const FormatException('Invalid operation');
    }
    if ((field == 'title' || field == 'site') && value.trim().isEmpty) {
      throw const FormatException('A value is required');
    }
    if (field == 'status' &&
        !['draft', 'in_progress', 'complete'].contains(value)) {
      throw const FormatException('Invalid status');
    }
    if (field == 'priority' &&
        !['normal', 'high', 'critical'].contains(value)) {
      throw const FormatException('Invalid priority');
    }
    if ((field == 'archived' || field.startsWith('check.')) &&
        !['true', 'false'].contains(value)) {
      throw const FormatException('Invalid checkbox');
    }
  }
  factory Operation.fromJson(Map<String, dynamic> json) => Operation(
    id: json['id'] as String,
    record: json['record'] as String,
    field: json['field'] as String,
    value: json['value'] as String,
    parents: List<String>.from(json['parents'] as List? ?? []),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'record': record,
    'field': field,
    'value': value,
    'parents': [...parents]..sort(),
  };
  bool equivalent(Operation other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());
}

List<Operation> frontier(
  Iterable<Operation> operations,
  String record,
  String field,
) {
  final matching = operations
      .where((o) => o.record == record && o.field == field)
      .toList();
  final removed = matching.expand((o) => o.parents).toSet();
  return matching.where((o) => !removed.contains(o.id)).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
}
