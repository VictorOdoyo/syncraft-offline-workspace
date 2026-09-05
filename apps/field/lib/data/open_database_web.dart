import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common/sqlite_api.dart';

Future<Database> openLocalDatabase(String name, OpenDatabaseOptions options) =>
    databaseFactoryFfiWeb.openDatabase(name, options: options);
