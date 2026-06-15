import 'package:flutter/material.dart';

class CartItem {
  final String name;
  final String? amount;
  bool isPurchased;

  CartItem({required this.name, this.amount, this.isPurchased = false});
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get unpurchasedCount => _items.where((e) => !e.isPurchased).length;

  bool hasItem(String name) => _items.any((e) => e.name == name);

  void addItem(String name, {String? amount}) {
    if (hasItem(name)) return;
    _items.add(CartItem(name: name, amount: amount));
    notifyListeners();
  }

  void addItems(List<CartItem> newItems) {
    bool changed = false;
    for (final item in newItems) {
      if (!hasItem(item.name)) {
        _items.add(CartItem(name: item.name, amount: item.amount));
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void togglePurchased(int index) {
    _items[index].isPurchased = !_items[index].isPurchased;
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void clearPurchased() {
    _items.removeWhere((e) => e.isPurchased);
    notifyListeners();
  }
}
