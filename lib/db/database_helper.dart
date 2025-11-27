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
  // INITIALIZE DATABASE (version 2, includes migration)
  // =============================================================
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,                   // 🔥 NEW VERSION
      onCreate: _createDB,
      onUpgrade: _upgradeDB,        // 🔥 MIGRATION ADDED
    );
  }

  // =============================================================
  // CREATE FULL DATABASE SCHEMA
  // =============================================================
  Future _createDB(Database db, int version) async {
    // ---------------------- Categories --------------------------
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        createdAt TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ------------------------- Items -----------------------------
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        createdAt TEXT NOT NULL DEFAULT (datetime('now')),
        updatedAt TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // -------------------- Invoice Transactions -------------------
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

    // ------------------------- Store Withdrawals -----------------
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
  // MIGRATION FROM VERSION 1 → VERSION 2
  // =============================================================
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add withdrawal table without touching data
      await db.execute('''
        CREATE TABLE IF NOT EXISTS store_withdrawals (
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
  }

  // =============================================================
  // ------------------------------- ITEMS ------------------------
  // =============================================================

  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('items', row);
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await instance.database;
    return await db.query('items', orderBy: 'createdAt DESC');
  }

  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    row['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('items', row,
        where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // =============================================================
  // --------------------------- CATEGORIES -----------------------
  // =============================================================

  Future<int> insertCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('categories', row);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // =============================================================
  // ---------------------- INVOICE TRANSACTIONS ------------------
  // (Already Exists — unchanged)
  // =============================================================

  Future<int> addStockTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('stock_transactions', row);
  }

  Future<List<Map<String, dynamic>>> getStockHistory(int itemId) async {
    final db = await instance.database;
    return await db.query(
      'stock_transactions',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'date DESC',
    );
  }

  Future<int> getCurrentStock(int itemId) async {
    final db = await instance.database;

    final result = await db.rawQuery('''
      SELECT 
        IFNULL(SUM(
          CASE WHEN type = 'IN' THEN quantity 
               WHEN type = 'OUT' THEN -quantity 
               ELSE 0 END
        ), 0) AS currentStock
      FROM stock_transactions
      WHERE itemId = ?
    ''', [itemId]);

    return result.first['currentStock'] as int;
  }

  // =============================================================
  // ------------------------ STORE WITHDRAWALS -------------------
  // (New Ledger — Internal stock movements)
  // =============================================================

  Future<int> addStoreWithdrawal(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('store_withdrawals', row);
  }

  Future<List<Map<String, dynamic>>> getStoreWithdrawals(int itemId) async {
    final db = await instance.database;
    return await db.query(
      'store_withdrawals',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'date DESC',
    );
  }

  Future<int> deleteStoreWithdrawal(int id) async {
    final db = await instance.database;
    return await db.delete(
      'store_withdrawals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getStoreStock(int itemId) async {
    final db = await instance.database;

    final result = await db.rawQuery('''
      SELECT 
        IFNULL(SUM(
          CASE WHEN type = 'IN' THEN quantity 
               WHEN type = 'OUT' THEN -quantity 
          END
        ), 0) AS storeStock
      FROM store_withdrawals
      WHERE itemId = ?
    ''', [itemId]);

    return result.first['storeStock'] as int;
  }

  // =============================================================
  // MISC
  // =============================================================

  Future<void> reloadDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await database;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}