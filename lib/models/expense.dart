class Expense {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String creatorId;
  final String creatorName;
  final DateTime createdAt;
  final String parentId;
  final String type;
  final Map<String, bool> paidBy;
  final Map<String, bool> calculatedBy;
  final bool isCalculated;

  Expense({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.creatorId,
    required this.creatorName,
    required this.createdAt,
    required this.parentId,
    required this.type,
    required this.paidBy,
    required this.calculatedBy,
    required this.isCalculated,
  });

  double get totalPrice => quantity * price;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'createdAt': createdAt,
      'parentId': parentId,
      'type': type,
      'paidBy': paidBy.map((key, value) => MapEntry(key, value)),
      'calculatedBy': calculatedBy.map((key, value) => MapEntry(key, value)),
      'isCalculated': isCalculated,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    Map<String, bool> paidBy = {};
    Map<String, bool> calculatedBy = {};
    
    // Harcamayı yapan kişinin ödemesi otomatik true
    paidBy[map['creatorId']] = true;
    
    // Diğer ödemeleri kontrol et
    if (map['paidBy'] != null) {
      (map['paidBy'] as Map<String, dynamic>).forEach((key, value) {
        // Eğer creator değilse, gelen değeri kullan
        if (key != map['creatorId']) {
          paidBy[key] = value == true;
        }
      });
    }

    // Hesaplama durumlarını kontrol et
    if (map['calculatedBy'] != null) {
      (map['calculatedBy'] as Map<String, dynamic>).forEach((key, value) {
        calculatedBy[key] = value == true;
      });
    }

    return Expense(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'].millisecondsSinceEpoch)
          : DateTime.now(),
      parentId: map['parentId'] ?? '',
      type: map['type'] ?? '',
      paidBy: paidBy,
      calculatedBy: calculatedBy,
      isCalculated: map['isCalculated'] ?? false,
    );
  }
}