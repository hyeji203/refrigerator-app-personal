import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/ingredient.dart';
import '../../../widgets/app_loading_indicator.dart';

class ReviewStep extends StatelessWidget {
  /// 인식된 재료 목록
  final List<ScanIngredientItem> items;

  /// 저장 API 호출 중 여부 (저장 버튼 비활성화에 사용)
  final bool isSaving;

  /// 전체 선택/해제 체크박스 콜백
  final ValueChanged<bool> onToggleAll;

  /// 개별 항목 체크박스 콜백 (index, 새 값)
  final void Function(int index, bool value) onToggleItem;

  /// 편집 아이콘 버튼 콜백 (index)
  final ValueChanged<int> onEditItem;

  /// 삭제 아이콘 버튼 콜백 (index)
  final ValueChanged<int> onRemoveItem;

  /// '재료 직접 추가' 버튼 콜백
  final VoidCallback onAddManual;

  /// '냉장고에 저장' 버튼 콜백
  final VoidCallback onSave;

  const ReviewStep({
    super.key,
    required this.items,
    required this.isSaving,
    required this.onToggleAll,
    required this.onToggleItem,
    required this.onEditItem,
    required this.onRemoveItem,
    required this.onAddManual,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount =
        items.where((i) => i.selected && i.name.isNotEmpty).length;
    final allSelected = items.every((i) => i.selected);

    return Column(
      key: const ValueKey('review'),
      children: [
        // ── 헤더 배너 ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          color: Colors.green.shade50,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI가 ${items.length}가지 재료를 인식했어요!\n저장할 재료를 확인하고 편집하세요.',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 재료 목록 ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              // 전체 선택 토글
              Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: (v) => onToggleAll(v ?? true),
                    activeColor: Colors.green,
                  ),
                  const Text('전체 선택',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '$selectedCount개 선택됨',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 8),

              // 개별 재료 카드
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                if (item.name.isEmpty) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    leading: Checkbox(
                      value: item.selected,
                      onChanged: (v) => onToggleItem(idx, v ?? false),
                      activeColor: Colors.green,
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: item.selected ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.quantity.isNotEmpty)
                          Text('수량: ${item.quantity}',
                              style: const TextStyle(fontSize: 12)),
                        if (item.expiryDate != null)
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                '유통기한: ${DateFormat('yyyy-MM-dd').format(item.expiryDate!)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.orange),
                              ),
                            ],
                          ),
                        if (item.quantity.isEmpty && item.expiryDate == null)
                          Text(
                            '탭하여 수량·유통기한 입력',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: Colors.blue),
                          onPressed: () => onEditItem(idx),
                          tooltip: '편집',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 20, color: Colors.red),
                          onPressed: () => onRemoveItem(idx),
                          tooltip: '삭제',
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // 재료 직접 추가
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.green),
                label: const Text('재료 직접 추가',
                    style: TextStyle(color: Colors.green)),
                onPressed: onAddManual,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // ── 저장 버튼 ──
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: isSaving
                  ? const AppLoadingIndicator()
                  : const Icon(Icons.save_alt),
              label: Text(
                isSaving ? '저장 중...' : '$selectedCount개 재료를 냉장고에 저장하기',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
