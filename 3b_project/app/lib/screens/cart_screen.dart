import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장바구니'),
        actions: [
          Consumer<CartService>(
            builder: (context, cart, _) {
              if (!cart.items.any((e) => e.isPurchased)) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: () {
                  cart.clearPurchased();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('구매 완료 항목을 삭제했습니다.')),
                  );
                },
                child: const Text('완료 삭제'),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cart, _) {
          if (cart.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('장바구니가 비어있어요',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('레시피에서 재료를 담거나 직접 추가해보세요.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return Slidable(
                key: ValueKey('$index-${item.name}'),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => cart.removeItem(index),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: '삭제',
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Checkbox(
                    value: item.isPurchased,
                    onChanged: (_) => cart.togglePurchased(index),
                    activeColor: Colors.green,
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      decoration:
                          item.isPurchased ? TextDecoration.lineThrough : null,
                      color: item.isPurchased ? Colors.grey : null,
                    ),
                  ),
                  subtitle: item.amount != null
                      ? Text(item.amount!,
                          style: const TextStyle(color: Colors.grey))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => cart.removeItem(index),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        tooltip: '직접 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('항목 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '재료명',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: '수량 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final amount = amountController.text.trim();
              context.read<CartService>().addItem(
                    name,
                    amount: amount.isEmpty ? null : amount,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

/// 앱바에 공통으로 사용하는 장바구니 아이콘 버튼 (미구매 수량 뱃지 포함)
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartService>(
      builder: (context, cart, _) {
        final count = cart.unpurchasedCount;
        return IconButton(
          tooltip: '장바구니',
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        );
      },
    );
  }
}
