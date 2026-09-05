import 'package:flutter/material.dart';

import '../domain/workspace_controller.dart';

Future<void> newInspection(
  BuildContext context,
  WorkspaceController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => _NewInspection(controller),
);

class _NewInspection extends StatefulWidget {
  final WorkspaceController controller;
  const _NewInspection(this.controller);
  @override
  State<_NewInspection> createState() => _NewInspectionState();
}

class _NewInspectionState extends State<_NewInspection> {
  final title = TextEditingController(), site = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    site.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New inspection'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: title,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Inspection title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: site,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Site'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a site' : null,
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                if (!form.currentState!.validate()) {
                  return;
                }
                setState(() => saving = true);
                try {
                  await widget.controller.create(title.text, site.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      error = e.toString();
                      saving = false;
                    });
                  }
                }
              },
        child: Text(saving ? 'Saving...' : 'Create'),
      ),
    ],
  );
}
