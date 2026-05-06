import 'dart:typed_data';

import 'package:flutter/material.dart';

class PreviewStep extends StatelessWidget {
  /// 미리보기에 표시할 이미지 바이트
  final Uint8List imageBytes;

  /// 'AI로 식재료 인식하기' 버튼 콜백
  final VoidCallback onAnalyze;

  /// '다른 사진 선택' 버튼 콜백
  final VoidCallback onReset;

  const PreviewStep({
    super.key,
    required this.imageBytes,
    required this.onAnalyze,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('preview'),
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(imageBytes, fit: BoxFit.cover),
              Container(color: Colors.black26),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '냉장고 내부가\n선명하게 보이나요?',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI로 식재료 인식하기',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: onAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('다른 사진 선택'),
                onPressed: onReset,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
