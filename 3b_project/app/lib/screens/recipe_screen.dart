import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/empty_state_widget.dart';
import 'cart_screen.dart';
import 'recipe_detail_screen.dart';
import 'recipe_history_screen.dart';
import '../services/api_service.dart';
import '../utils/allergy.dart';
import '../utils/error_message.dart';

class RecipeScreen extends StatefulWidget {
  final bool showOnlySaved;
  const RecipeScreen({super.key, this.showOnlySaved = false});

  @override
  State<RecipeScreen> createState() => RecipeScreenState();
}

class RecipeScreenState extends State<RecipeScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _loadError; // 목록 로드 실패 시 사용자용 오류 문장
  bool _isRecommending = false;

  bool _isSearching = false;
  List<Recipe> _searchResults = [];
  bool _isSearchLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchRecipes(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isSearchLoading = true);
    try {
      final response = await ApiService.dio.post(
        '/recipes/recommend-by-ingredient/$userId',
        queryParameters: {'ingredient': keyword.trim()},
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final List data = response.data;
      setState(
          () => _searchResults = data.map((e) => Recipe.fromJson(e)).toList());
      if (!mounted) return;
      if (_searchResults.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "'${keyword.trim()}' 레시피 ${_searchResults.length}개를 찾았어요!")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(e,
              fallback: '레시피를 찾지 못했어요. 잠시 후 다시 시도해 주세요.')),
          action: SnackBarAction(
              label: '다시 시도', onPressed: () => _searchRecipes(keyword)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> loadRecipes() => _loadRecipes();

  Future<void> _loadRecipes() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await ApiService.dio.get('/recipes/user/$userId');
      final List data = response.data;
      final all = data.map((e) => Recipe.fromJson(e)).toList();
      setState(() => _recipes = widget.showOnlySaved
          ? all.where((r) => r.isSaved == 1).toList()
          : all);
    } catch (e) {
      // 실패를 빈 목록으로 보여주지 않고 오류 화면으로 구분
      setState(() => _loadError = friendlyErrorMessage(e,
          fallback: '레시피 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recommendRecipes() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isRecommending = true);
    try {
      final response = await ApiService.dio.post(
        '/recipes/recommend/$userId',
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final List data = response.data;
      final newRecipes = data.map((e) => Recipe.fromJson(e)).toList();
      setState(() => _recipes = [...newRecipes, ..._recipes]);
      if (!mounted) return;
      final allergies =
          parseAllergies(context.read<AuthService>().allergies);
      final String message;
      if (newRecipes.isEmpty) {
        message = allergies.isEmpty
            ? '추천할 수 있는 레시피가 없어요. 냉장고에 재료를 추가해 보세요.'
            : '알레르기 재료를 제외하니 추천할 레시피가 없어요. 냉장고에 재료를 더 추가해 보세요.';
      } else {
        message = allergies.isEmpty
            ? '새로운 레시피를 추천받았어요!'
            : '알레르기 재료(${allergies.join(', ')})를 빼고 추천했어요!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(e,
              fallback: '레시피를 추천받지 못했어요. 잠시 후 다시 시도해 주세요.')),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '다시 시도', onPressed: _recommendRecipes),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRecommending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSearch,
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '재료 이름을 입력하세요 (예: 계란)',
                  border: InputBorder.none,
                ),
                onSubmitted: _searchRecipes,
              ),
              actions: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchRecipes(_searchController.text),
                ),
              ],
            )
          : AppBar(
              title: Text(widget.showOnlySaved ? '북마크한 레시피' : '추천 레시피'),
              actions: [
                const CartIconButton(),
                if (!widget.showOnlySaved)
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: '검색',
                    onPressed: _startSearch,
                  ),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '레시피 기록',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RecipeHistoryScreen()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.bookmark),
                    tooltip: '북마크한 레시피',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const RecipeScreen(showOnlySaved: true),
                        ),
                      );
                      _loadRecipes();
                    },
                  ),
                ),
              ],
            ),
      body: _isSearching
          ? _isSearchLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AI가 레시피를 생성 중이에요...'),
                    ],
                  ),
                )
              : _searchResults.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.search_off,
                      title: '검색 결과가 없어요',
                      subtitle: '재료 이름을 입력하고 검색 버튼을 눌러보세요',
                    )
                  : _buildRecipeList(_searchResults)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (!widget.showOnlySaved)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isRecommending
                                ? const AppLoadingIndicator()
                                : const Icon(Icons.auto_awesome),
                            label: Text(_isRecommending
                                ? 'AI가 레시피를 생성 중...'
                                : 'AI 레시피 추천받기'),
                            onPressed:
                                _isRecommending ? null : _recommendRecipes,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // 레시피 목록
                    Expanded(
                      child: _loadError != null
                          ? EmptyStateWidget(
                              icon: Icons.cloud_off_outlined,
                              title: '레시피를 불러오지 못했어요',
                              subtitle: _loadError,
                              actionLabel: '다시 시도',
                              onAction: _loadRecipes,
                            )
                          : _recipes.isEmpty
                          ? const EmptyStateWidget(
                              icon: Icons.restaurant_menu_outlined,
                              title: '아직 추천된 레시피가 없어요',
                              subtitle: '위 버튼을 눌러 AI 레시피를 추천받아보세요!',
                            )
                          : _buildRecipeList(_recipes),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRecipeList(List<Recipe> recipes) {
    final allergies = parseAllergies(context.watch<AuthService>().allergies);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final recipeAllergens =
            matchRecipeAllergens(recipe.ingredientLines, allergies);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(recipe.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (recipe.cookingTime != null) ...[
                      const Icon(Icons.timer, size: 14, color: Colors.grey),
                      Text(' ${recipe.cookingTime}분  ',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                    if (recipe.difficulty != null) ...[
                      const Icon(Icons.bar_chart, size: 14, color: Colors.grey),
                      Text(' ${recipe.difficulty}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
                if (recipeAllergens.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red[700], size: 16),
                        Expanded(
                          child: Text(
                              '  알레르기 주의: ${recipeAllergens.join(', ')}',
                              style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                if (recipe.youtubeUrl != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_filled,
                            color: Colors.red, size: 16),
                        Text('  YouTube 영상 있음',
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                recipe.isSaved == 1 ? Icons.bookmark : Icons.bookmark_outline,
                color: recipe.isSaved == 1 ? Colors.amber : Colors.grey,
              ),
              onPressed: () async {
                try {
                  await ApiService.dio
                      .patch('/recipes/${recipe.recipeId}/save');
                  final newState = recipe.isSaved == 1 ? 0 : 1;
                  final updated = Recipe(
                    recipeId: recipe.recipeId,
                    title: recipe.title,
                    description: recipe.description,
                    cookingTime: recipe.cookingTime,
                    difficulty: recipe.difficulty,
                    servings: recipe.servings,
                    youtubeUrl: recipe.youtubeUrl,
                    youtubeTitle: recipe.youtubeTitle,
                    isSaved: newState,
                    createdAt: recipe.createdAt,
                    viewedAt: recipe.viewedAt,
                    ingredients: recipe.ingredients,
                  );
                  setState(() {
                    if (recipes == _searchResults) {
                      _searchResults[index] = updated;
                    } else {
                      _recipes[index] = updated;
                    }
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(newState == 1 ? '북마크가 설정되었습니다' : '북마크가 해제되었습니다'),
                      duration: const Duration(milliseconds: 2500),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(friendlyErrorMessage(e,
                          fallback: '북마크를 변경하지 못했어요. 잠시 후 다시 시도해 주세요.')),
                    ),
                  );
                }
              },
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: recipe),
                ),
              );
              _loadRecipes();
            },
          ),
        );
      },
    );
  }
}
