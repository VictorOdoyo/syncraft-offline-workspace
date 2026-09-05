import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openLocalDatabase(String name, OpenDatabaseOptions options) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive:true);
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    return databaseFactoryFfi.openDatabase(path.join(directory.path,name),options:options);
  }
  return mobile.databaseFactory.openDatabase(path.join(directory.path,name),options:options);
}
