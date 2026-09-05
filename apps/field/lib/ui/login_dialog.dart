import 'package:flutter/material.dart';

import '../sync/sync_engine.dart';

Future<bool> loginDialog(BuildContext context, SyncEngine engine) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _LoginDialog(engine),
    ) ??
    false;

class _LoginDialog extends StatefulWidget {
  final SyncEngine engine;
  const _LoginDialog(this.engine);
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final username = TextEditingController(text: 'inspector'),
      password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Connect workspace'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: username,
            autofocus: true,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xffb42336)),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await widget.engine.login(
                    username.text.trim(),
                    password.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      error = e.toString();
                      busy = false;
                    });
                  }
                }
              },
        child: Text(busy ? 'Connecting...' : 'Connect'),
      ),
    ],
  );
}
