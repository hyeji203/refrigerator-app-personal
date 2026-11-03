import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'allergy_screen.dart';

/// 첫 실행 시 한 번 보여주는 짧은 사용법 안내 (3장)
class OnboardingScreen extends StatefulWidget {
  /// 온보딩을 본 적 있는지 저장하는 SharedPreferences 키
  static const doneKey = 'onboardingDone';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingPage(this.icon, this.title, this.body);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingPage(
      Icons.kitchen,
      '냉장고 재료를 한눈에',
      '재료를 등록하면 유통기한이 가까운 순서로 보여드려요.\n'
          '임박한 재료는 냉장고 탭에 숫자로 표시돼요.',
    ),
    _OnboardingPage(
      Icons.camera_alt,
      '사진 한 장으로 등록',
      '냉장고나 장 본 재료를 찍으면 AI가 재료를 찾아줘요.\n'
          '확인하고 고친 다음 한 번에 저장하세요.',
    ),
    _OnboardingPage(
      Icons.restaurant_menu,
      '있는 재료로 레시피 추천',
      '가진 재료로 만들 수 있는 요리를 AI가 추천해요.\n'
          '알레르기를 등록하면 해당 재료는 빼고 추천해요.',
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      Navigator.pop(context);
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _prev() {
    _controller.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _goTo(int i) {
    _controller.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _openAllergy() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AllergyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 첫 장이 아니면 이전 설명으로 돌아갈 수 있게
                AnimatedOpacity(
                  opacity: _index == 0 ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton.icon(
                    onPressed: _index == 0 ? null : _prev,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('이전'),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _isLast ? null : () => Navigator.pop(context),
                    child: const Text('건너뛰기'),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                // 웹/데스크탑에서도 마우스 드래그로 넘길 수 있게
                scrollBehavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                ),
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 64,
                          backgroundColor: primary.withValues(alpha: 0.12),
                          child: Icon(page.icon, size: 64, color: primary),
                        ),
                        const SizedBox(height: 40),
                        Text(page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text(page.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.grey[700])),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 페이지 위치 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                // 점을 눌러 원하는 장으로 바로 이동
                (i) => GestureDetector(
                  onTap: () => _goTo(i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? primary : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? '시작하기' : '다음',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
            // 마지막 장: 추천 정확도에 중요한 알레르기 설정으로 바로 이동
            SizedBox(
              height: 48,
              child: _isLast
                  ? TextButton(
                      onPressed: _openAllergy,
                      child: const Text('알레르기 먼저 등록하기'),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
