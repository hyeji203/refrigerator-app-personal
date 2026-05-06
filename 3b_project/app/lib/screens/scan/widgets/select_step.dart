import 'package:flutter/material.dart';

class SelectStep extends StatelessWidget {
  /// 카메라로 촬영하기 버튼 콜백
  final VoidCallback onPickCamera;

  /// 갤러리에서 선택하기 버튼 콜백
  final VoidCallback onPickGallery;

  const SelectStep({
    super.key,
    required this.onPickCamera,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('select'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Icon(Icons.kitchen, size: 80, color: Colors.green.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              '냉장고 사진을 촬영하면\nAI가 재료를 자동으로 인식합니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt, size: 24),
                label: const Text('카메라로 촬영하기',
                    style: TextStyle(fontSize: 16)),
                onPressed: onPickCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library, size: 24),
                label: const Text('갤러리에서 선택하기',
                    style: TextStyle(fontSize: 16)),
                onPressed: onPickGallery,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green, width: 1.5),
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
