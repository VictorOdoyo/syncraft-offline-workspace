import 'dart:async';

import 'package:flutter/material.dart';

import '../sync/sync_engine.dart';
import 'confirm.dart';

class DevicesPanel extends StatefulWidget {
  final SyncEngine sync;
  const DevicesPanel({super.key, required this.sync});
  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState extends State<DevicesPanel> {
  List<dynamic> devices = [];
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final result = await widget.sync.api.get('/api/v1/devices') as List;
      if (mounted) {
        setState(() {
          devices = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Registered devices',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Refresh devices',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Color(0xffb42336))),
      for (final d in devices)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            d['revoked'] == true ? Icons.phonelink_erase : Icons.tablet_android,
          ),
          title: Text(d['name'] as String),
          subtitle: Text(
            '${d['actor']}\n${d['id']}${d['id'] == widget.sync.api.device ? ' (this device)' : ''}',
          ),
          isThreeLine: true,
          trailing: d['revoked'] == true
              ? const Text('Revoked')
              : IconButton(
                  tooltip: 'Revoke device',
                  icon: const Icon(Icons.block),
                  onPressed: () async {
                    if (await confirm(
                      context,
                      'Revoke device?',
                      d['name'] as String,
                      'Revoke',
                    )) {
                      try {
                        await widget.sync.api.post(
                          '/api/v1/devices/${d['id']}/revoke',
                          {},
                        );
                        if (d['id'] == widget.sync.api.device) {
                          widget.sync.logout();
                        }
                        await load();
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      }
                    }
                  },
                ),
        ),
    ],
  );
}
