import 'package:flutter/material.dart';

import '../../../models/ingredient.dart';

class ExpiryNotificationPanel extends StatelessWidget {
  final List<Ingredient> expiringIngredients;

  const ExpiryNotificationPanel({
    super.key,
    required this.expiringIngredients,
  });

  static void show(BuildContext context, List<Ingredient> expiringIngredients) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExpiryNotificationPanel(
        expiringIngredients: expiringIngredients,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 드래그 핸들
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                '유통기한 임박 알림',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (expiringIngredients.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${expiringIngredients.length}개',
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
        // 목록
        if (expiringIngredients.isEmpty)
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
            itemCount: expiringIngredients.length,
            itemBuilder: (ctx, i) {
              final item = expiringIngredients[i];
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
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: item.expiryDate != null
                    ? Text('유통기한: ${item.expiryDate}')
                    : null,
                trailing: daysLeft != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: daysLeft <= 1
                              ? Colors.red
                              : Colors.orange,
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
    );
  }
}
