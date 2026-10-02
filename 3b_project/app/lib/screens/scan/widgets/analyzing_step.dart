import 'dart:typed_data';

import 'package:flutter/material.dart';

class AnalyzingStep extends StatelessWidget {
  /// 분석 중 표시할 이미지 바이트 (null이면 이미지 생략)
  final Uint8List? imageBytes;

  /// 부모의 AnimationController에서 생성된 펄스 애니메이션
  final Animation<double> pulseAnim;

  /// 사진 업로드 진행률 (0.0 ~ 1.0)
  final double uploadProgress;

  /// 분석 시작 후 경과 시간(초)
  final int elapsedSeconds;

  /// 분석 취소
  final VoidCallback onCancel;

  const AnalyzingStep({
    super.key,
    required this.imageBytes,
    required this.pulseAnim,
    required this.uploadProgress,
    required this.elapsedSeconds,
    required this.onCancel,
  });

  bool get _isUploading => uploadProgress < 1.0;

  // 업로드 → 인식 → 오래 걸릴 때 순서로 단계별 안내
  String get _stageMessage {
    if (_isUploading) {
      return '사진을 올리고 있어요 (${(uploadProgress * 100).round()}%)';
    }
    if (elapsedSeconds < 20) return '사진 속 재료를 찾고 있어요';
    return '재료가 많으면 조금 더 걸려요. 잠시만 기다려 주세요';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('analyzing'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
            // 업로드 중에는 실제 진행률, 이후에는 진행 중 표시
            LinearProgressIndicator(
              value: _isUploading ? uploadProgress : null,
              color: Colors.green,
              backgroundColor: Colors.green.shade50,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI가 식재료를 분석하고 있어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _stageMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              '$elapsedSeconds초 경과 · 다른 탭을 봐도 분석은 계속돼요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('분석 취소'),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
