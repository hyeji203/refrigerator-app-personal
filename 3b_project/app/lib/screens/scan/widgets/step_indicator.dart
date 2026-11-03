import 'package:flutter/material.dart';

/// 스캔 진행 단계 표시 (1 사진 선택 → 2 AI 분석 → 3 재료 확인 → 4 저장 완료)
class ScanStepIndicator extends StatelessWidget implements PreferredSizeWidget {
  /// 현재 단계 (0부터 시작)
  final int currentIndex;

  static const labels = ['사진 선택', 'AI 분석', '재료 확인', '저장 완료'];

  const ScanStepIndicator({super.key, required this.currentIndex});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final inactive = Colors.grey.shade400;

    final children = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final isDone = i < currentIndex;
      final isCurrent = i == currentIndex;
      final color = isDone || isCurrent ? primary : inactive;

      if (i > 0) {
        // 단계 사이 연결선 (원 중앙 높이에 맞춤)
        children.add(Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 18),
            color: i <= currentIndex ? primary : Colors.grey.shade300,
          ),
        ));
      }

      children.add(Semantics(
        label: '${i + 1}단계 ${labels[i]}${isCurrent ? ', 현재 단계' : isDone ? ', 완료' : ''}',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDone || isCurrent ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : inactive,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? primary
                      : isDone
                          ? Colors.grey.shade700
                          : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ));
    }

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}
