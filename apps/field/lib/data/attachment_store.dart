import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'local_store.dart';
import '../domain/operation.dart';
import '../sync/api_client.dart';

class AttachmentStore {
  final LocalStore local;
  AttachmentStore(this.local);
  Future<String> add(
    String record,
    String name,
    String media,
    Uint8List bytes,
  ) async {
    if (!idPattern.hasMatch(record) ||
        name.isEmpty ||
        name.length > 200 ||
        name.contains(RegExp(r'[/\\\r\n]')) ||
        bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024 ||
        ![
          'image/jpeg',
          'image/png',
          'application/pdf',
          'text/plain',
        ].contains(media)) {
      throw const FormatException(
        'Use a JPG, PNG, PDF, or text file up to 5 MiB.',
      );
    }
    final id = const Uuid().v4();
    await local.db.insert('attachments', {
      'id': id,
      'record': record,
      'name': name,
      'media_type': media,
      'sha256': sha256.convert(bytes).toString(),
      'content': bytes,
    });
    return id;
  }

  Future<List<Map<String, Object?>>> list(String record) => local.db.query(
    'attachments',
    columns: ['id', 'record', 'name', 'media_type', 'sha256', 'uploaded'],
    where: 'record=?',
    whereArgs: [record],
    orderBy: 'name,id',
  );
  Future<Uint8List> bytes(String id) async =>
      (await local.db.query(
            'attachments',
            columns: ['content'],
            where: 'id=?',
            whereArgs: [id],
          )).single['content']
          as Uint8List;
  Future<void> uploadPending(ApiClient api) async {
    final pending = await local.db.query(
      'attachments',
      where: 'uploaded=0',
      limit: 10,
    );
    for (final row in pending) {
      final result = await api.upload(
        row['id'] as String,
        row['record'] as String,
        row['name'] as String,
        row['media_type'] as String,
        row['content'] as Uint8List,
      );
      if (result['sha256'] != row['sha256']) {
        throw const FormatException('Attachment checksum mismatch');
      }
      await local.db.update(
        'attachments',
        {'uploaded': 1},
        where: 'id=?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> fetch(ApiClient api, String record) async {
    final remote = await api.get('/api/v1/attachments?record=$record') as List;
    for (final raw in remote) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id'] as String;
      if ((await local.db.query(
        'attachments',
        columns: ['id'],
        where: 'id=?',
        whereArgs: [id],
      )).isNotEmpty) {
        continue;
      }
      if (row['size'] is! int || (row['size'] as int) > 5 * 1024 * 1024) {
        throw const FormatException('Attachment too large');
      }
      final data = await api.download(id);
      if (sha256.convert(data).toString() != row['sha256']) {
        throw const FormatException('Attachment checksum mismatch');
      }
      await local.db.insert('attachments', {
        'id': id,
        'record': record,
        'name': row['name'],
        'media_type': row['type'],
        'sha256': row['sha256'],
        'content': data,
        'uploaded': 1,
      });
    }
  }
}
