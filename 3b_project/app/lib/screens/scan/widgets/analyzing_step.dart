import 'dart:typed_data';

import 'package:flutter/material.dart';

class AnalyzingStep extends StatelessWidget {
  /// 분석 중 표시할 이미지 바이트 (null이면 이미지 생략)
  final Uint8List? imageBytes;

  /// 부모의 AnimationController에서 생성된 펄스 애니메이션
  final Animation<double> pulseAnim;

  const AnalyzingStep({
    super.key,
    required this.imageBytes,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('analyzing'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageBytes != null)
            ScaleTransition(
              scale: pulseAnim,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(imageBytes!, fit: BoxFit.cover),
                ),
              ),
            ),
          const SizedBox(height: 40),
          const CircularProgressIndicator(
              color: Colors.green, strokeWidth: 3),
          const SizedBox(height: 24),
          const Text(
            'AI가 식재료를 분석하고 있어요',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Gemini Vision이 냉장고 안을 확인 중...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
