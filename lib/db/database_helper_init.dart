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

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // ---------- CATEGORIES ----------
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        createdAt TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ---------- ITEMS ----------
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        categoryId INTEGER,
        createdAt TEXT NOT NULL DEFAULT (datetime('now')),
        updatedAt TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // ---------- STOCK TRANSACTIONS ----------
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
  }

  // ---------- CRUD FOR CATEGORIES ----------
  Future<int> insertCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('categories', row);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;
    return await db.query('categories', orderBy: 'name COLLATE NOCASE ASC');
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- CRUD FOR ITEMS ----------
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
    int id = row['id'];
    row['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('items', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- STOCK TRANSACTIONS ----------
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
      SELECT IFNULL(SUM(
        CASE WHEN type = 'IN' THEN quantity 
             WHEN type = 'OUT' THEN -quantity 
             ELSE 0 END
      ), 0) AS currentStock
      FROM stock_transactions
      WHERE itemId = ?
    ''', [itemId]);
    return result.first['currentStock'] as int;
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
  }
}