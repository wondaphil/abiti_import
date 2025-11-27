import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('import_db.db');
    return _database!;
  }

  // =============================================================
  // INITIALIZE DATABASE (VERSION 3)
  // =============================================================
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // =============================================================
  // CREATE FULL SCHEMA (VERSION 3)
  // =============================================================
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        createdAt TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        photo BLOB,                                  -- NEW COLUMN
        createdAt TEXT NOT NULL DEFAULT (datetime('now')),
        updatedAt TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        type TEXT CHECK(type IN ('IN', 'OUT')) NOT NULL,
        date TEXT NOT NULL DEFAULT (datetime('now')),
        receiptNo TEXT,
        notes TEXT,
        FOREIGN KEY (itemId) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE store_withdrawals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        type TEXT CHECK(type IN ('IN', 'OUT')) NOT NULL,
        date TEXT NOT NULL DEFAULT (datetime('now')),
        notes TEXT,
        FOREIGN KEY (itemId) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');
  }

  // =============================================================
  // MIGRATIONS
  // =============================================================
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS store_withdrawals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          itemId INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          type TEXT CHECK(type IN ('IN','OUT')) NOT NULL,
          date TEXT NOT NULL DEFAULT (datetime('now')),
          notes TEXT,
          FOREIGN KEY (itemId) REFERENCES items(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      // ADD PHOTO COLUMN IF NOT EXISTS
      await db.execute('ALTER TABLE items ADD COLUMN photo BLOB');
    }
  }

  // =============================================================
  // ITEMS CRUD
  // =============================================================
  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('items', row);
  }

  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    row['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('items', row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // =============================================================
  // CATEGORY CRUD
  // =============================================================
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;
    return db.query('categories', orderBy: 'name ASC');
  }

  Future<int> insertCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    return db.insert('categories', row);
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // =============================================================
  // INVOICE TX
  // =============================================================
  Future<int> addStockTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return db.insert('stock_transactions', row);
  }

  Future<List<Map<String, dynamic>>> getStockHistory(int itemId) async {
    final db = await instance.database;
    return db.query('stock_transactions',
        where: 'itemId = ?', whereArgs: [itemId], orderBy: 'date DESC');
  }

  Future<int> getCurrentStock(int itemId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT IFNULL(SUM(
        CASE WHEN type='IN' THEN quantity
             WHEN type='OUT' THEN -quantity END
      ),0) AS total
      FROM stock_transactions WHERE itemId=?
    ''', [itemId]);

    return result.first['total'] as int;
  }

  // =============================================================
  // STORE LEDGER
  // =============================================================
  Future<int> addStoreWithdrawal(Map<String, dynamic> row) async {
    final db = await instance.database;
    return db.insert('store_withdrawals', row);
  }

  Future<List<Map<String, dynamic>>> getStoreWithdrawals(int id) async {
    final db = await instance.database;
    return db.query('store_withdrawals',
        where: 'itemId=?', whereArgs: [id], orderBy: 'date DESC');
  }

  Future<int> deleteStoreWithdrawal(int id) async {
    final db = await instance.database;
    return db.delete('store_withdrawals', where: 'id=?', whereArgs: [id]);
  }

  Future<int> getStoreStock(int id) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
    SELECT IFNULL(SUM(
      CASE WHEN type='IN' THEN quantity
           WHEN type='OUT' THEN -quantity END
    ),0) AS total
    FROM store_withdrawals WHERE itemId=?
    ''', [id]);
    return result.first['total'] as int;
  }

  // =============================================================
  Future<void> reloadDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await database; // reopen automatically
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
