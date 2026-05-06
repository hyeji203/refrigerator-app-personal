import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../models/ingredient.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../widgets/empty_state_widget.dart';
import 'widgets/expiry_notification_panel.dart';
import 'widgets/ingredient_action_dialog.dart';

class IngredientScreen extends StatefulWidget {
  const IngredientScreen({super.key});

  @override
  State<IngredientScreen> createState() => IngredientScreenState();
}

class IngredientScreenState extends State<IngredientScreen> {
  List<Ingredient> _ingredients = [];
  List<Ingredient> _expiringIngredients = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> loadIngredients() => _loadIngredients();

  Future<void> _loadIngredients() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        IngredientApiService.getIngredients(userId),
        IngredientApiService.getExpiringIngredients(userId),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('서버 응답 시간이 초과됐습니다. 서버가 실행 중인지 확인해주세요.'),
      );
      if (!mounted) return;
      setState(() {
        _ingredients = results[0];
        _expiringIngredients = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('식재료를 불러오는 중 오류: $e'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '재시도', onPressed: _loadIngredients),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IngredientActionDialog(onSaved: _loadIngredients),
    );
  }

  void _openEditDialog(Ingredient ingredient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IngredientActionDialog(
        ingredient: ingredient,
        onSaved: _loadIngredients,
      ),
    );
  }

  Future<void> _confirmDelete(Ingredient ingredient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${ingredient.ingredientName}을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await IngredientApiService.deleteIngredient(ingredient.userIngredientId);
      _loadIngredients();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 냉장고'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => ExpiryNotificationPanel.show(
                    context, _expiringIngredients),
                tooltip: '유통기한 알림',
              ),
              if (_expiringIngredients.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _expiringIngredients.length > 9
                            ? '9+'
                            : '${_expiringIngredients.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIngredients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ingredients.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.kitchen_outlined,
                  title: '냉장고가 비어있어요!',
                  subtitle: '연필 버튼으로 재료를 추가하거나\n카메라로 스캔해보세요',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = _ingredients[index];
                    return Slidable(
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => _openEditDialog(ingredient),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            icon: Icons.edit,
                            label: '수정',
                          ),
                          SlidableAction(
                            onPressed: (_) => _confirmDelete(ingredient),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: '삭제',
                          ),
                        ],
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          onTap: () => _openEditDialog(ingredient),
                          leading: CircleAvatar(
                            backgroundColor: ingredient.expiringSoon
                                ? Colors.red[100]
                                : Colors.green[100],
                            child: Icon(
                              Icons.food_bank,
                              color: ingredient.expiringSoon
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                          title: Text(ingredient.ingredientName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            [
                              if (ingredient.quantity != null)
                                ingredient.quantity!,
                              if (ingredient.expiryDate != null)
                                '유통기한: ${ingredient.expiryDate}',
                            ].join(' · '),
                          ),
                          trailing: ingredient.expiringSoon
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Text('곧 만료',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11)),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
