import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/empty_state_widget.dart';
import 'recipe_detail_screen.dart';

class RecipeHistoryScreen extends StatefulWidget {
  const RecipeHistoryScreen({super.key});

  @override
  State<RecipeHistoryScreen> createState() => _RecipeHistoryScreenState();
}

class _RecipeHistoryScreenState extends State<RecipeHistoryScreen> {
  List<Recipe> _history = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isLoading = true);
    await _loadFromCache(userId);
    try {
      final response =
          await ApiService.dio.get('/recipes/user/$userId/history');
      final List data = response.data;
      setState(() => _history = data.map((e) => Recipe.fromJson(e)).toList());
      _saveToCache(userId, data);
    } catch (_) {
      // 서버 오프라인 시 캐시 유지
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFromCache(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('recipe_history_cache_$userId');
    if (cached != null) {
      final List data = jsonDecode(cached);
      setState(() => _history =
          data.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList());
    }
  }

  Future<void> _saveToCache(int userId, List data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recipe_history_cache_$userId', jsonEncode(data));
  }

  String _formatViewedAt(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('최근 본 레시피')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.history,
                  title: '최근 본 레시피가 없어요',
                  subtitle: '레시피를 눌러서 확인하면 여기에 기록이 남아요',
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final recipe = _history[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          recipe.isSaved == 1
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          color:
                              recipe.isSaved == 1 ? Colors.amber : Colors.grey,
                        ),
                        title: Text(
                          recipe.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _formatViewedAt(recipe.viewedAt),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: recipe.youtubeUrl != null
                            ? const Icon(Icons.play_circle_filled,
                                color: Colors.red, size: 20)
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: recipe),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
