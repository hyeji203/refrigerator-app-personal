class ScanIngredientItem {
  String name;
  String quantity;
  DateTime? expiryDate;
  bool selected;

  ScanIngredientItem({
    required this.name,
    this.quantity = '',
    this.expiryDate,
    this.selected = true,
  });
}

class Ingredient {
  final int userIngredientId;
  final String ingredientName;
  final String? quantity;
  final String? expiryDate;
  final String addedMethod;
  final String status;
  final bool expiringSoon;

  Ingredient({
    required this.userIngredientId,
    required this.ingredientName,
    this.quantity,
    this.expiryDate,
    required this.addedMethod,
    required this.status,
    required this.expiringSoon,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      userIngredientId: json['userIngredientId'],
      ingredientName: json['ingredientName'],
      quantity: json['quantity'],
      expiryDate: json['expiryDate'],
      addedMethod: json['addedMethod'] ?? 'MANUAL',
      status: json['status'] ?? 'ACTIVE',
      expiringSoon: json['expiringSoon'] ?? false,
    );
  }
}
