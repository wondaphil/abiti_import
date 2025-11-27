class Item {
  final int? id;
  final String code;
  final String name;
  final int? categoryId;
  final String? description;
  final String createdAt;
  final String updatedAt;

  Item({
    this.id,
	this.categoryId,
    required this.code,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      code: map['code'],
      name: map['name'],
      description: map['description'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}