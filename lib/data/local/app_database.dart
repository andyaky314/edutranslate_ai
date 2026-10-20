import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this.database);

  final Database database;

  static const schemaVersion = 2;

  static Future<AppDatabase> open() async {
    final path = await _databasePath();
    final database = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return AppDatabase._(database);
  }

  static Future<String> _databasePath() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final directory = await getApplicationSupportDirectory();
        await Directory(directory.path).create(recursive: true);
        return p.join(directory.path, 'edutranslate.db');
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return p.join(await getDatabasesPath(), 'edutranslate.db');
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Local database storage is not configured for Fuchsia.',
        );
    }
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE translation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        createdAt TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE vocabulary (
        id TEXT PRIMARY KEY,
        word TEXT NOT NULL,
        language TEXT NOT NULL,
        meaning TEXT NOT NULL,
        explanation TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        reviewCount INTEGER NOT NULL DEFAULT 0,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createSchema(db, newVersion);
    }
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS dictionary_entries');
    }
  }

  Future<void> close() => database.close();
}
