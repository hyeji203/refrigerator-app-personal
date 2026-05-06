import 'package:flutter/material.dart';

class DoneStep extends StatelessWidget {
  /// 저장 완료된 재료 개수
  final int savedCount;

  /// '다시 스캔하기' 버튼 콜백
  final VoidCallback onReset;

  const DoneStep({
    super.key,
    required this.savedCount,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('done'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle,
                  size: 72, color: Colors.green.shade500),
            ),
            const SizedBox(height: 28),
            const Text(
              '저장 완료!',
              style:
                  TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '$savedCount가지 재료가 냉장고에 추가되었어요.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '유통기한을 입력한 재료는\n알림이 자동으로 등록되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('다시 스캔하기',
                    style: TextStyle(fontSize: 15)),
                onPressed: onReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
