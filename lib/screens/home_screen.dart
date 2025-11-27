import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'manage_categories_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  List<Map<String, dynamic>> categories = [];
  int? selectedCategoryId;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadItems();
  }

  Future<void> _loadCategories() async {
    final db = DatabaseHelper.instance;
    final result = await db.getAllCategories();
    setState(() => categories = result);
  }

  Future<void> _loadItems() async {
    final db = DatabaseHelper.instance;

    final result = await db.database.then((dbConn) => dbConn.rawQuery('''
      SELECT 
        i.id, 
        i.code, 
        i.name, 
        i.description, 
        i.categoryId,
        i.photo,                           -- <-- NEW COLUMN
        c.name AS category,

        IFNULL(SUM(
          CASE 
            WHEN t.type = 'IN' THEN t.quantity 
            WHEN t.type = 'OUT' THEN -t.quantity 
          END
        ), 0) AS invoice_stock,

        (
          SELECT IFNULL(SUM(
            CASE WHEN sw.type='IN' THEN sw.quantity
                 WHEN sw.type='OUT' THEN -sw.quantity END
          ), 0)
          FROM store_withdrawals sw
          WHERE sw.itemId = i.id
        ) AS store_stock,

        CAST((
          SELECT COUNT(*) FROM store_withdrawals sw WHERE sw.itemId = i.id
        ) AS INTEGER) AS st_count,

        COUNT(t.id) AS tx_count

      FROM items i
      LEFT JOIN categories c ON i.categoryId = c.id
      LEFT JOIN stock_transactions t ON i.id = t.itemId
      GROUP BY i.id
      ORDER BY i.name COLLATE NOCASE ASC
    '''));

    setState(() {
      allItems = result;
      _applyFilters();
    });
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: item['name']);
    final descCtrl = TextEditingController(text: item['description']);
    final codeCtrl = TextEditingController(text: item['code']);

    final db = DatabaseHelper.instance;
    final categories = await db.getAllCategories();

    int? categoryId = item['categoryId'];
    if (categoryId != null &&
        !categories.any((c) => c['id'] == categoryId)) {
      categoryId = null;
    }

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...categories.map((c) => DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['name']),
                      )),
                ],
                onChanged: (v) => categoryId = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;

              await db.updateItem({
                'id': item['id'],
                'code': codeCtrl.text,
                'name': nameCtrl.text,
                'description': descCtrl.text,
                'categoryId': categoryId,
              });

              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true) _loadItems();
  }

  Future<void> _deleteItem(int id) async {
    final db = DatabaseHelper.instance;

    final itemData =
        await (await db.database).rawQuery('SELECT name FROM items WHERE id = ?', [id]);

    final itemName =
        itemData.isNotEmpty ? itemData.first['name'] as String : 'this item';

    final stock = await db.getCurrentStock(id);

    String message = 'Are you sure you want to delete "$itemName"?';
    if (stock > 0) {
      message +=
          '\n\n⚠️ This item still has $stock units in stock. Its history will also be removed.';
    } else {
      message += '\n\nThis item has no remaining stock.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.deleteItem(id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "$itemName"')),
      );

      _loadItems();
    }
  }

  void _applyFilters() {
    setState(() {
      filteredItems = allItems.where((item) {
        final matchesCategory =
            selectedCategoryId == null || item['categoryId'] == selectedCategoryId;

        final matchesSearch = searchQuery.isEmpty ||
            (item['name'] ?? '')
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            (item['description'] ?? '')
                .toLowerCase()
                .contains(searchQuery.toLowerCase());

        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void _openAddItem() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );
    _loadItems();
  }

  void _openManageCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
    );
    _loadCategories();
    _loadItems();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/logo_icon.png',
                height: 28,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Abiti Import',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: _openManageCategories,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              final imported = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (imported == true) {
                _loadItems();
                _loadCategories();
              }
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItem,
        label: const Text('Add Item'),
        icon: const Icon(Icons.add),
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // SEARCH
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            searchQuery = '';
                            _applyFilters();
                          });
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                searchQuery = value;
                _applyFilters();
              },
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<int>(
              value: selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Filter by Category',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text("All Categories")),
                ...categories.map((c) =>
                    DropdownMenuItem(value: c['id'], child: Text(c['name']))),
              ],
              onChanged: (v) {
                selectedCategoryId = v;
                _applyFilters();
              },
            ),

            const SizedBox(height: 12),

            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text('No items found'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final Uint8List? photo = item['photo'];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItemDetailScreen(item: item),
                                ),
                              ).then((_) => _loadItems());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ------------------ THUMBNAIL ---------------------
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: photo != null
                                        ? Image.memory(
                                            photo,
                                            width: 38,
                                            height: 38,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _placeholderThumb(),
                                          )
                                        : _placeholderThumb(),
                                  ),

                                  const SizedBox(width: 14),

                                  // ---------------- TEXT COLUMN --------------------
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if ((item['description'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              item['description'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 6),

                                        // ------------ STOCK LINES ---------------------
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['tx_count'] == 0
                                                  ? 'Invoice stock: No transactions yet'
                                                  : (item['invoice_stock'] == 0
                                                      ? 'Invoice stock: Out of stock'
                                                      : 'Invoice stock: ${item['invoice_stock']}'),
                                              style: TextStyle(
                                                color: item['tx_count'] == 0
                                                    ? Colors.grey
                                                    : (item['invoice_stock'] > 0
                                                        ? Colors.green
                                                        : Colors.redAccent),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              item['st_count'] == 0
                                                  ? 'Store stock: No transactions yet'
                                                  : (item['store_stock'] == 0
                                                      ? 'Store stock: Out of stock'
                                                      : 'Store stock: ${item['store_stock']}'),
                                              style: TextStyle(
                                                color: item['st_count'] == 0
                                                    ? Colors.grey
                                                    : (item['store_stock'] > 0
                                                        ? Colors.green
                                                        : Colors.redAccent),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editItem(item);
                                      } else if (value == 'delete') {
                                        _deleteItem(item['id']);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline,
                                                color: Colors.redAccent,
                                                size: 20),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          size: 20, color: Colors.grey),
    );
  }
}