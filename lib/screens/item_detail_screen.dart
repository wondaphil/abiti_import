import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';

class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int invoiceStock = 0;
  List<Map<String, dynamic>> invoiceTx = [];

  int storeStock = 0;
  List<Map<String, dynamic>> storeTx = [];

  Uint8List? itemPhoto;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load photo from map (already Uint8List? or null)
    if (widget.item.containsKey('photo') && widget.item['photo'] != null) {
      itemPhoto = widget.item['photo'];
    }

    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadInvoiceLedger();
    await _loadStoreLedger();
  }

  // =========================================================
  // INVOICE LEDGER
  // =========================================================
  Future<void> _loadInvoiceLedger() async {
    final db = await DatabaseHelper.instance.database;

    final stock = await db.rawQuery('''
      SELECT IFNULL(SUM(
        CASE WHEN type='IN' THEN quantity
             WHEN type='OUT' THEN -quantity
        END), 0) AS total
      FROM stock_transactions WHERE itemId = ?
    ''', [widget.item['id']]);

    final hist = await db.query(
      'stock_transactions',
      where: 'itemId = ?',
      whereArgs: [widget.item['id']],
      orderBy: 'date DESC',
    );

    setState(() {
      invoiceStock = stock.first['total'] as int;
      invoiceTx = hist;
    });
  }

  // =========================================================
  // STORE LEDGER
  // =========================================================
  Future<void> _loadStoreLedger() async {
    final db = DatabaseHelper.instance;

    final stock = await db.getStoreStock(widget.item['id']);
    final hist = await db.getStoreWithdrawals(widget.item['id']);

    setState(() {
      storeStock = stock;
      storeTx = hist;
    });
  }

  String _formatDate(String iso) {
    final d = DateTime.parse(iso);
    return DateFormat("yyyy-MM-dd").format(d);
  }

  // =========================================================
  // FULL SCREEN VIEWER FOR PHOTO
  // =========================================================
  void _openFullImage() {
    if (itemPhoto == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(
                itemPhoto!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 120,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DIALOGS
  // =========================================================
  Future<void> _openInvoiceDialog({Map<String, dynamic>? tx, String? initType}) async {
    final qtyCtrl = TextEditingController(text: tx?['quantity']?.toString() ?? '');
    final receiptCtrl = TextEditingController(text: tx?['receiptNo'] ?? '');
    final notesCtrl = TextEditingController(text: tx?['notes'] ?? '');
    String type = tx?['type'] ?? (initType ?? 'IN');

    DateTime selectedDate =
        tx != null ? DateTime.parse(tx['date']) : DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(tx == null ? 'Add Stock Transaction'
                                 : 'Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'IN', child: Text('Invoice In')),
                    DropdownMenuItem(value: 'OUT', child: Text('Invoice Out')),
                  ],
                  onChanged: (v) => type = v!,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: receiptCtrl,
                  decoration: const InputDecoration(labelText: 'Receipt No.'),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Date:', style: TextStyle(fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setStateDialog(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text);
                if (qty == null || qty <= 0) return;

                final db = await DatabaseHelper.instance.database;
                final payload = {
                  'itemId': widget.item['id'],
                  'quantity': qty,
                  'type': type,
                  'date': selectedDate.toIso8601String(),
                  'receiptNo': receiptCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                };

                if (tx == null) {
                  await db.insert('stock_transactions', payload);
                } else {
                  await db.update(
                    'stock_transactions',
                    payload,
                    where: "id = ?",
                    whereArgs: [tx['id']],
                  );
                }

                Navigator.pop(context, true);
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );

    if (saved == true) _loadInvoiceLedger();
  }

  Future<void> _openStoreDialog({String type = "OUT"}) async {
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(type == "IN" ? "Store IN (Return)" : "Store OUT"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Date:', style: TextStyle(fontSize: 16)),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                  )
                ],
              ),

              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text);
                if (qty == null || qty <= 0) return;

                final db = DatabaseHelper.instance;
                await db.addStoreWithdrawal({
                  'itemId': widget.item['id'],
                  'quantity': qty,
                  'type': type,
                  'date': selectedDate.toIso8601String(),
                  'notes': notesCtrl.text.trim(),
                });

                Navigator.pop(context, true);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );

    if (saved == true) _loadStoreLedger();
  }

  // =========================================================
  // DELETE TX
  // =========================================================
  Future<void> _deleteInvoice(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Transaction"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          )
        ],
      ),
    );

    if (ok == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete("stock_transactions", where: "id = ?", whereArgs: [id]);
      _loadInvoiceLedger();
    }
  }

  Future<void> _deleteStore(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Store Transaction"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          )
        ],
      ),
    );

    if (ok == true) {
      final db = DatabaseHelper.instance;
      await db.deleteStoreWithdrawal(id);
      _loadStoreLedger();
    }
  }

  // =========================================================
  // FLOATING BUTTON BUILDERS
  // =========================================================
  Widget _buildInvoiceFABs() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'inv_in',
          onPressed: () => _openInvoiceDialog(initType: 'IN'),
          icon: const Icon(Icons.arrow_downward),
          label: const Text("Invoice IN"),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'inv_out',
          backgroundColor: Colors.redAccent,
          onPressed: () => _openInvoiceDialog(initType: 'OUT'),
          icon: const Icon(Icons.arrow_upward),
          label: const Text("Invoice OUT"),
        ),
      ],
    );
  }

  Widget _buildStoreFABs() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'store_in',
          onPressed: () => _openStoreDialog(type: 'IN'),
          icon: const Icon(Icons.arrow_downward),
          label: const Text("Store IN"),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'store_out',
          backgroundColor: Colors.redAccent,
          onPressed: () => _openStoreDialog(type: 'OUT'),
          icon: const Icon(Icons.arrow_upward),
          label: const Text("Store OUT"),
        ),
      ],
    );
  }

  // =========================================================
  // INVOICE UI
  // =========================================================
  Widget _buildInvoiceUI() {
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------
          // SMALL THUMBNAIL
          // ----------------------------------------------------
          if (itemPhoto != null)
			  GestureDetector(
				onTap: _openFullImage,
				child: Center(
				  child: ClipRRect(
					borderRadius: BorderRadius.circular(8),
					child: Image.memory(
					  itemPhoto!,
					  width: 120,
					  height: 120,
					  fit: BoxFit.cover,
					  errorBuilder: (_, __, ___) => Container(
						color: Colors.grey.shade300,
						width: 120,
						height: 120,
						child: const Icon(Icons.broken_image),
					  ),
					),
				  ),
				),
			  )
			else
			  Center( // Add this Center widget
				child: Container(
				  width: 120,
				  height: 120,
				  decoration: BoxDecoration(
					color: Colors.grey.shade300,
					borderRadius: BorderRadius.circular(8),
				  ),
				  child: const Icon(Icons.photo, size: 40),
				),
			  ),

          const SizedBox(height: 16),

          Text("Code: ${item['code']}"),
          Text("Description: ${item['description'] ?? ''}"),
          const SizedBox(height: 12),

          Text(
            "Current Invoiced Stock: $invoiceStock",
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const Divider(height: 30),
          const Text("Transaction History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),

          Expanded(
            child: invoiceTx.isEmpty
                ? const Center(child: Text("No stock transactions yet"))
                : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 120,
                    ),
                    itemCount: invoiceTx.length,
                    itemBuilder: (_, i) {
                      final tx = invoiceTx[i];
                      final isIn = tx['type'] == 'IN';
                      final qty = tx['quantity'];
                      final date = _formatDate(tx['date']);
                      final notes = tx['notes'] ?? "";
                      final receipt = tx['receiptNo'] ?? "";

                      String subtitle = date;
                      if (receipt.isNotEmpty) subtitle += "\nReceipt: $receipt";
                      if (notes.isNotEmpty) subtitle += "\n$notes";

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isIn ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIn ? Colors.teal : Colors.redAccent,
                          ),
                          title: Text(
                            "${isIn ? '+' : '-'}$qty pcs",
                            style: TextStyle(
                              color: isIn ? Colors.teal : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(subtitle),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _openInvoiceDialog(tx: tx);
                              if (v == 'delete') _deleteInvoice(tx['id']);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined),
                                    SizedBox(width: 8),
                                    Text("Edit"),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    SizedBox(width: 8),
                                    Text("Delete"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STORE UI
  // =========================================================
  Widget _buildStoreUI() {
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------
          // PHOTO THUMBNAIL
          // ----------------------------------------------------
          if (itemPhoto != null)
			  GestureDetector(
				onTap: _openFullImage,
				child: Center(
				  child: ClipRRect(
					borderRadius: BorderRadius.circular(8),
					child: Image.memory(
					  itemPhoto!,
					  width: 120,
					  height: 120,
					  fit: BoxFit.cover,
					  errorBuilder: (_, __, ___) => Container(
						color: Colors.grey.shade300,
						width: 120,
						height: 120,
						child: const Icon(Icons.broken_image),
					  ),
					),
				  ),
				),
			  )
			else
			  Center( // Add this Center widget
				child: Container(
				  width: 120,
				  height: 120,
				  decoration: BoxDecoration(
					color: Colors.grey.shade300,
					borderRadius: BorderRadius.circular(8),
				  ),
				  child: const Icon(Icons.photo, size: 40),
				),
			  ),

          const SizedBox(height: 16),

          Text("Code: ${item['code']}"),
          Text("Description: ${item['description'] ?? ''}"),
          const SizedBox(height: 12),

          Text(
            "Current Store Stock: $storeStock",
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const Divider(height: 30),
          const Text("Store Transaction History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Expanded(
            child: storeTx.isEmpty
                ? const Center(child: Text("No store transactions yet"))
                : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 120,
                    ),
                    itemCount: storeTx.length,
                    itemBuilder: (_, i) {
                      final tx = storeTx[i];
                      final isIn = tx['type'] == 'IN';
                      final qty = tx['quantity'];
                      final date = _formatDate(tx['date']);
                      final notes = tx['notes'] ?? "";

                      String subtitle = date;
                      if (notes.isNotEmpty) subtitle += "\n$notes";

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isIn ? Icons.add : Icons.remove,
                            color: isIn ? Colors.green : Colors.redAccent,
                          ),
                          title: Text(
                            "${isIn ? '+' : '-'}$qty pcs",
                            style: TextStyle(
                              color: isIn ? Colors.green : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(subtitle),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'delete') _deleteStore(tx['id']);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    SizedBox(width: 8),
                                    Text("Delete"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

    // =========================================================
  // CSV EXPORT
  // =========================================================
  Future<void> _exportToCSV() async {
    final db = await DatabaseHelper.instance.database;
    final item = widget.item;
    final itemId = item['id'];

    String categoryName = '';
    try {
      final cat = await db.rawQuery('''
        SELECT c.name AS category
        FROM categories c
        JOIN items i ON i.categoryId = c.id
        WHERE i.id = ?
      ''', [itemId]);

      if (cat.isNotEmpty && cat.first['category'] != null) {
        categoryName = cat.first['category'].toString();
      }
    } catch (_) {}

    final txs = await db.query(
      'stock_transactions',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'date ASC',
    );

    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export.')),
      );
      return;
    }

    final rows = <List<dynamic>>[];
    rows.add(['Item Name', 'Category', 'Date', 'Receipt No.', 'Notes', 'IN', 'OUT', 'STOCK']);

    int runningStock = 0;
    int totalIn = 0;
    int totalOut = 0;

    for (final tx in txs) {
      final date = tx['date']?.toString() ?? '';
      final qty = int.tryParse(tx['quantity'].toString()) ?? 0;
      final type = tx['type']?.toString() ?? '';
      final receipt = tx['receiptNo']?.toString() ?? '';
      final notes = tx['notes']?.toString() ?? '';

      final parsedDate = DateTime.tryParse(date);
      final dateText = parsedDate != null
          ? DateFormat('yyyy-MM-dd').format(parsedDate)
          : date;

      int inQty = 0;
      int outQty = 0;

      if (type == 'IN') {
        inQty = qty;
        totalIn += qty;
        runningStock += qty;
      } else if (type == 'OUT') {
        outQty = qty;
        totalOut += qty;
        runningStock -= qty;
      }

      rows.add([
        item['name'],
        categoryName,
        dateText,
        receipt,
        notes,
        inQty == 0 ? '' : inQty,
        outQty == 0 ? '' : outQty,
        runningStock,
      ]);
    }

    rows.add([]);
    rows.add(['TOTALS', '', '', '', '', totalIn, totalOut, runningStock]);

    final csvText = const ListToCsvConverter().convert(rows);
    final csvBytes =
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvText)]);

    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/${item['name']}_transactions.csv');
    await file.writeAsBytes(csvBytes);

    await Share.shareXFiles([XFile(file.path)]);
  }

  // =========================================================
  // BUILD METHOD (REQUIRED!)
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item['name'] ?? 'Item Details'),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _exportToCSV,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Invoice'),
            Tab(text: 'Store'),
          ],
          onTap: (_) => setState(() {}),
        ),
      ),

      floatingActionButton:
          _tabController.index == 0 ? _buildInvoiceFABs() : _buildStoreFABs(),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvoiceUI(),
          _buildStoreUI(),
        ],
      ),
    );
  }
}
