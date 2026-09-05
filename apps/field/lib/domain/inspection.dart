import 'operation.dart';

class Inspection {
  final String id;
  final Map<String, List<Operation>> fields;
  Inspection(this.id, this.fields);
  String value(String field, [String fallback = '']) =>
      fields[field]?.firstOrNull?.value ?? fallback;
  String get title => value('title', 'Untitled inspection');
  String get site => value('site', 'Unspecified site');
  String get status => value('status', 'draft');
  String get priority => value('priority', 'normal');
  bool get archived =>
      fields['archived']?.any((o) => o.value == 'true') ?? false;
  List<String> get conflicts =>
      fields.entries
          .where((e) => e.value.map((o) => o.value).toSet().length > 1)
          .map((e) => e.key)
          .toList()
        ..sort();
  int get checked => [
    'check.safety',
    'check.equipment',
    'check.access',
  ].where((f) => value(f) == 'true' && !conflicts.contains(f)).length;
  static List<Inspection> project(Iterable<Operation> ops) {
    final list = ops.toList();
    return list
        .map((o) => o.record)
        .toSet()
        .map(
          (id) => Inspection(id, {
            for (final field in fieldLimits.keys)
              field: frontier(list, id, field),
          }),
        )
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}
