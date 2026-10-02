import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'ingredient/ingredient_screen.dart';
import 'recipe_screen.dart';
import 'scan/scan_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _scanTab = 1;

  int _currentIndex = 0;
  bool _isScanAnalyzing = false;
  int _expiringCount = 0; // 냉장고 탭 배지 (유통기한 임박·만료 재료 수)
  final GlobalKey<IngredientScreenState> _ingredientKey = GlobalKey();
  final GlobalKey<RecipeScreenState> _recipeKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      IngredientScreen(
        key: _ingredientKey,
        onExpiringCountChanged: (count) {
          if (mounted) setState(() => _expiringCount = count);
        },
      ),
      ScanScreen(
        onAnalyzingChanged: (v) => setState(() => _isScanAnalyzing = v),
        onAnalyzeCompleted: _onScanCompleted,
      ),
      RecipeScreen(key: _recipeKey),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboardingOnce());
  }

  // 처음 홈에 들어왔을 때 한 번만 앱 사용법 안내
  Future<void> _showOnboardingOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(OnboardingScreen.doneKey) == true || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => const OnboardingScreen()),
    );
    await prefs.setBool(OnboardingScreen.doneKey, true);
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    // IndexedStack은 화면을 유지하므로, 목록 화면은 탭할 때 새로고침
    if (index == 0) {
      _ingredientKey.currentState?.loadIngredients();
    } else if (index == 2) {
      _recipeKey.currentState?.loadRecipes();
    }
  }

  // 다른 탭에 있는 동안 분석이 끝나면 알려주고 바로 이동할 수 있게 함
  void _onScanCompleted() {
    if (_currentIndex == _scanTab || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('사진 분석이 끝났어요. 인식된 재료를 확인해 주세요.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '확인하기',
          onPressed: () => _onTabTap(_scanTab),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 탭을 옮겨도 각 화면의 상태(스캔 진행 상황 등)가 유지되도록 IndexedStack 사용
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            // 유통기한 임박 재료 수를 표시해 다른 탭에서도 알 수 있게 함
            icon: Badge(
              isLabelVisible: _expiringCount > 0,
              label: Text(_expiringCount > 99 ? '99+' : '$_expiringCount'),
              child: const Icon(Icons.kitchen),
            ),
            label: '냉장고',
            tooltip:
                _expiringCount > 0 ? '냉장고 (유통기한 임박 $_expiringCount개)' : '냉장고',
          ),
          BottomNavigationBarItem(
            // 분석 중에는 스캔 탭에 점을 표시해 다른 탭에서도 진행 중임을 알 수 있게 함
            icon: Badge(
              isLabelVisible: _isScanAnalyzing,
              smallSize: 8,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.camera_alt),
            ),
            label: _isScanAnalyzing ? '분석 중' : '스캔',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: '레시피',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}
