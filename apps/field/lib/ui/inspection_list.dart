import 'package:flutter/material.dart';

import '../domain/workspace_controller.dart';
import 'theme.dart';

class InspectionList extends StatelessWidget {
  final WorkspaceController controller;
  const InspectionList({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final records = controller.filtered;
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fact_check_outlined, size: 44, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No inspections match'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: controller.clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = records[index];
        final active = record.id == controller.selectedId;
        return Card(
          color: active ? const Color(0xffe3f4ef) : Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => controller.select(record.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: priorityColor(record.priority),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          record.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (record.conflicts.isNotEmpty)
                        Tooltip(
                          message:
                              '${record.conflicts.length} unresolved fields',
                          child: const Icon(
                            Icons.compare_arrows,
                            color: Color(0xffb42336),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      record.site,
                      style: const TextStyle(color: Color(0xff596970)),
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(label(record.status)),
                      Text(
                        label(record.priority),
                        style: TextStyle(
                          color: priorityColor(record.priority),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('${record.checked}/3 checks'),
                      if (record.conflicts.isNotEmpty)
                        Text(
                          '${record.conflicts.length} conflicts',
                          style: const TextStyle(color: Color(0xffb42336)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
