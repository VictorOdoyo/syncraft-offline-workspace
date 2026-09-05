import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/recovery.dart';
import '../domain/workspace_controller.dart';
import 'confirm.dart';

class RecoveryPanel extends StatefulWidget {
  final WorkspaceController controller;
  const RecoveryPanel({super.key, required this.controller});
  @override
  State<RecoveryPanel> createState() => _RecoveryPanelState();
}

class _RecoveryPanelState extends State<RecoveryPanel> {
  bool busy = false;
  String? result;
  Future<void> run(Future<String> Function() action) async {
    setState(() => busy = true);
    try {
      final message = await action();
      if (mounted) {
        setState(() => result = message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => result = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Device recovery',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      const Text(
        'Recovery files contain inspection records and attachments. Store them in a trusted location.',
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: busy
            ? null
            : () => run(() async {
                final bytes = await RecoveryBundle.export(
                  widget.controller.store,
                );
                final saved = await FilePicker.saveFile(
                  fileName: 'syncraft-recovery.json',
                  bytes: bytes,
                );
                return saved == null ? 'Export cancelled.' : 'Recovery export saved.';
              }),
        icon: const Icon(Icons.save_alt),
        label: const Text('Export recovery file'),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed:
            busy ||
                widget.controller.sync.connected ||
                widget.controller.inspections.isNotEmpty
            ? null
            : () => run(() async {
                final file = await FilePicker.pickFile(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );
                if (file == null) {
                  return 'Restore cancelled.';
                }
                if (!context.mounted ||
                    !await confirm(
                      context,
                      'Restore device data?',
                      'A new device identity will be created and restored edits will be queued for synchronization.',
                      'Restore',
                    )) {
                  return 'Restore cancelled.';
                }
                if (file.size > RecoveryBundle.maxBytes) { throw const FormatException('Recovery file exceeds 50 MiB'); }
                final bytes = await file.readAsBytes();
                final count = await RecoveryBundle.restore(
                  widget.controller.store,
                  bytes,
                );
                await widget.controller.refresh();
                return 'Restored $count operations.';
              }),
        icon: const Icon(Icons.settings_backup_restore),
        label: const Text('Restore into empty device'),
      ),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      if (result != null)
        Padding(padding: const EdgeInsets.only(top: 20), child: Text(result!)),
    ],
  );
}
