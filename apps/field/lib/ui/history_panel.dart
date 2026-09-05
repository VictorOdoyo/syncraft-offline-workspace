import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/local_store.dart';

class HistoryPanel extends StatelessWidget {
  final LocalStore store;
  final String record;
  const HistoryPanel({super.key, required this.store, required this.record});
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: store.db.query('operations', orderBy: 'position DESC'),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('History could not be loaded');
      }
      if (!snapshot.hasData) {
        return const LinearProgressIndicator();
      }
      final rows = snapshot.data!
          .where(
            (r) =>
                (jsonDecode(r['content'] as String) as Map)['record'] == record,
          )
          .take(100);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit history',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '${(jsonDecode(row['content'] as String) as Map)['field']} updated',
              ),
              subtitle: Text('${row['actor']} · ${row['created']}'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SelectableText(
                      (jsonDecode(row['content'] as String) as Map)['value']
                          as String,
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    },
  );
}
