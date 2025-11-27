class StockTransaction {
  final int? id;
  final int itemId;
  final int quantity;
  final String type; // 'IN' or 'OUT'
  final String date;
  final String? notes;

  StockTransaction({
    this.id,
    required this.itemId,
    required this.quantity,
    required this.type,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'quantity': quantity,
      'type': type,
      'date': date,
      'notes': notes,
    };
  }

  factory StockTransaction.fromMap(Map<String, dynamic> map) {
    return StockTransaction(
      id: map['id'],
      itemId: map['itemId'],
      quantity: map['quantity'],
      type: map['type'],
      date: map['date'],
      notes: map['notes'],
    );
  }
}