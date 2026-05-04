import 'package:flutter/material.dart';
import 'ingredient_screen.dart';
import 'recipe_screen.dart';
import 'scan_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<IngredientScreenState> _ingredientKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      IngredientScreen(key: _ingredientKey),
      const ScanScreen(),
      const RecipeScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      _ingredientKey.currentState?.loadIngredients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen),
            label: '냉장고',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: '스캔',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: '레시피',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}
