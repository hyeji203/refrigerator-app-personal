import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/empty_state_widget.dart';
import 'recipe_detail_screen.dart';
import '../services/api_service.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  bool _isRecommending = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/recipes/user/$userId');
      final List data = response.data;
      setState(() => _recipes = data.map((e) => Recipe.fromJson(e)).toList());
    } catch (e) {
      // 오류 처리
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recommendRecipes() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isRecommending = true);
    try {
      final response = await ApiService.dio.post('/recipes/recommend/$userId');
      final List data = response.data;
      final newRecipes = data.map((e) => Recipe.fromJson(e)).toList();
      setState(() => _recipes = [...newRecipes, ..._recipes]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새로운 레시피를 추천받았어요!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레시피 추천 중 오류: $e')),
      );
    } finally {
      setState(() => _isRecommending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('추천 레시피'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecipes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 레시피 추천 버튼
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isRecommending
                          ? const AppLoadingIndicator()
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                          _isRecommending ? 'AI가 레시피를 생성 중...' : 'AI 레시피 추천받기'),
                      onPressed: _isRecommending ? null : _recommendRecipes,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),

                // 레시피 목록
                Expanded(
                  child: _recipes.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.restaurant_menu_outlined,
                          title: '아직 추천된 레시피가 없어요',
                          subtitle: '위 버튼을 눌러 AI 레시피를 추천받아보세요!',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _recipes.length,
                          itemBuilder: (context, index) {
                            final recipe = _recipes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(recipe.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (recipe.cookingTime != null) ...[
                                          const Icon(Icons.timer,
                                              size: 14, color: Colors.grey),
                                          Text(' ${recipe.cookingTime}분  ',
                                              style: const TextStyle(
                                                  color: Colors.grey)),
                                        ],
                                        if (recipe.difficulty != null) ...[
                                          const Icon(Icons.bar_chart,
                                              size: 14, color: Colors.grey),
                                          Text(' ${recipe.difficulty}',
                                              style: const TextStyle(
                                                  color: Colors.grey)),
                                        ],
                                      ],
                                    ),
                                    if (recipe.youtubeUrl != null)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.play_circle_filled,
                                                color: Colors.red, size: 16),
                                            Text('  YouTube 영상 있음',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Icon(
                                  recipe.isSaved == 1
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  color: recipe.isSaved == 1
                                      ? Colors.amber
                                      : Colors.grey,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RecipeDetailScreen(recipe: recipe),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
