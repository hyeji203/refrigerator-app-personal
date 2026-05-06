import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/ingredient.dart';
import '../services/auth_service.dart';
import '../services/ingredient_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/ingredient_form.dart';

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
      ]);
      setState(() {
        _ingredients = results[0];
        _expiringIngredients = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('식재료를 불러오는 중 오류: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExpiryNotificationPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  '유통기한 임박 알림',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_expiringIngredients.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_expiringIngredients.length}개',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_expiringIngredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text('유통기한 임박 재료가 없어요!',
                      style: TextStyle(fontSize: 15, color: Colors.grey)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _expiringIngredients.length,
              itemBuilder: (ctx, i) {
                final item = _expiringIngredients[i];
                final daysLeft = item.expiryDate != null
                    ? DateTime.tryParse(item.expiryDate!)
                        ?.difference(DateTime.now())
                        .inDays
                    : null;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: daysLeft != null && daysLeft <= 1
                        ? Colors.red[100]
                        : Colors.orange[100],
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: daysLeft != null && daysLeft <= 1
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                  title: Text(item.ingredientName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: item.expiryDate != null
                      ? Text('유통기한: ${item.expiryDate}')
                      : null,
                  trailing: daysLeft != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: daysLeft <= 1 ? Colors.red : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            daysLeft == 0
                                ? '오늘 만료'
                                : daysLeft < 0
                                    ? '만료됨'
                                    : 'D-$daysLeft',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        )
                      : null,
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showEditDialog(Ingredient ingredient) {
    final formKey = GlobalKey<IngredientFormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('식재료 수정'),
          content: IngredientForm(
            key: formKey,
            initialName: ingredient.ingredientName,
            initialQuantity: ingredient.quantity ?? '',
            initialExpiryDate: ingredient.expiryDate != null
                ? DateTime.tryParse(ingredient.expiryDate!)
                : null,
            firstDate: DateTime(2020),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _confirmDelete(ingredient);
                    },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
            const Spacer(),
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final form = formKey.currentState!;
                      if (form.name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('재료명을 입력해주세요')),
                        );
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      final expiryStr = form.expiryDate != null
                          ? DateFormat('yyyy-MM-dd').format(form.expiryDate!)
                          : null;
                      try {
                        await IngredientApiService.updateIngredient(
                          ingredient.userIngredientId,
                          {
                            'ingredientName': form.name,
                            'quantity': form.quantity.isEmpty ? null : form.quantity,
                            'expiryDate': expiryStr,
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadIngredients();
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('수정 실패: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const AppLoadingIndicator(size: 16)
                  : const Text('저장'),
            ),
          ],
        ),
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
            child:
                const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await IngredientApiService.deleteIngredient(
            ingredient.userIngredientId);
        _loadIngredients();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddDialog() {
    final formKey = GlobalKey<IngredientFormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('식재료 추가'),
          content: IngredientForm(key: formKey),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final form = formKey.currentState!;
                      if (form.name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('재료명을 입력해주세요')),
                        );
                        return;
                      }
                      final userId = context.read<AuthService>().userId;
                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인이 필요합니다')),
                        );
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      final expiryStr = form.expiryDate != null
                          ? DateFormat('yyyy-MM-dd').format(form.expiryDate!)
                          : null;
                      try {
                        final added = await IngredientApiService.addIngredient(
                          userId,
                          {
                            'ingredientName': form.name,
                            'quantity': form.quantity.isEmpty ? null : form.quantity,
                            'expiryDate': expiryStr,
                            'addedMethod': 'MANUAL',
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadIngredients();
                        if (expiryStr != null) {
                          try {
                            await NotificationService.scheduleExpiryAlert(
                              id: added.userIngredientId,
                              ingredientName: added.ingredientName,
                              expiryDateStr: expiryStr,
                            );
                          } catch (_) {}
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('식재료 추가 실패: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const AppLoadingIndicator(size: 16)
                  : const Text('추가'),
            ),
          ],
        ),
      ),
    );
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
                onPressed: _showExpiryNotificationPanel,
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
                            onPressed: (_) => _showEditDialog(ingredient),
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
                          onTap: () => _showEditDialog(ingredient),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('곧 만료',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
