import 'package:flutter/material.dart';

import '../domain/inspection.dart';
import '../domain/workspace_controller.dart';
import 'conflict_panel.dart';
import 'edit_field.dart';
import 'confirm.dart';
import 'theme.dart';

class InspectionDetail extends StatelessWidget {
  final Inspection record;
  final WorkspaceController controller;
  final Widget? attachments;
  final Widget? history;
  const InspectionDetail({
    super.key,
    required this.record,
    required this.controller,
    this.attachments,
    this.history,
  });
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Close inspection',
            onPressed: () => controller.select(null),
            icon: const Icon(Icons.close),
          ),
          const Spacer(),
          TextButton.icon(
            icon: Icon(
              record.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
            label: Text(record.archived ? 'Restore' : 'Archive'),
            onPressed: () async {
              if (await confirm(
                context,
                record.archived ? 'Restore inspection?' : 'Archive inspection?',
                record.title,
                record.archived ? 'Restore' : 'Archive',
              )) {
                try {
                  await controller.archive(record, !record.archived);
                } catch (e) {
                  if (context.mounted) {
                    showError(context, e);
                  }
                }
              }
            },
          ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              record.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Edit title',
            onPressed: () => editField(
              context,
              controller,
              record.id,
              'title',
              record.fields['title']!,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(record.site)),
          IconButton(
            tooltip: 'Edit site',
            onPressed: () => editField(
              context,
              controller,
              record.id,
              'site',
              record.fields['site']!,
            ),
            icon: const Icon(Icons.edit_location_alt_outlined),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: record.status,
              key: ValueKey('${record.id}-${record.status}'),
              decoration: const InputDecoration(labelText: 'Status'),
              items: const ['draft', 'in_progress', 'complete']
                  .map((s) => DropdownMenuItem(value: s, child: Text(label(s))))
                  .toList(),
              onChanged: record.conflicts.contains('status')
                  ? null
                  : (value) async {
                      if (value == null) {
                        return;
                      }
                      try {
                        await controller.edit(
                          record.id,
                          'status',
                          value,
                          record.fields['status']!.map((o) => o.id).toList(),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      }
                    },
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: record.priority,
              key: ValueKey('${record.id}-${record.priority}'),
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                'normal',
                'high',
                'critical',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: record.conflicts.contains('priority')
                  ? null
                  : (value) async {
                      if (value == null) {
                        return;
                      }
                      try {
                        await controller.edit(
                          record.id,
                          'priority',
                          value,
                          record.fields['priority']!.map((o) => o.id).toList(),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      }
                    },
            ),
          ),
        ],
      ),
      ConflictPanel(record: record, controller: controller),
      const SizedBox(height: 24),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Field notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Edit notes',
            onPressed: () => editField(
              context,
              controller,
              record.id,
              'notes',
              record.fields['notes']!,
            ),
            icon: const Icon(Icons.edit_note),
          ),
        ],
      ),
      SelectionArea(child: Text(record.value('notes', 'No notes recorded.'))),
      const SizedBox(height: 24),
      const Text(
        'Inspection checks',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      for (final entry in {
        'check.safety': 'Safety conditions confirmed',
        'check.equipment': 'Equipment examined',
        'check.access': 'Access and handover checked',
      }.entries)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          value: record.value(entry.key) == 'true',
          subtitle: record.conflicts.contains(entry.key)
              ? const Text('Resolve concurrent values above')
              : null,
          onChanged: record.conflicts.contains(entry.key)
              ? null
              : (value) async {
                  try {
                    await controller.edit(
                      record.id,
                      entry.key,
                      '${value ?? false}',
                      record.fields[entry.key]!.map((o) => o.id).toList(),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      showError(context, e);
                    }
                  }
                },
        ),
      if (attachments != null) ...[const Divider(height: 40), attachments!],
      if (history != null) ...[const Divider(height: 40), history!],
    ],
  );
}
