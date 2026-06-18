import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.recipe.isSaved;
    ApiService.dio
        .patch('/recipes/${widget.recipe.recipeId}/view')
        .catchError((_) {});
  }

  Future<void> _toggleBookmark() async {
    try {
      await ApiService.dio.patch('/recipes/${widget.recipe.recipeId}/save');
      final newState = _isSaved == 1 ? 0 : 1;
      setState(() => _isSaved = newState);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState == 1 ? '북마크가 설정되었습니다' : '북마크가 해제되었습니다'),
          duration: const Duration(milliseconds: 2500),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('북마크 변경에 실패했습니다')),
      );
    }
  }

  static List<String> _parseIngredients(String? description) {
    if (description == null || description.isEmpty) return [];
    for (final line in description.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('주재료:')) {
        return trimmed
            .substring('주재료:'.length)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  static List<String> _parseSteps(String? description) {
    if (description == null || description.isEmpty) return [];
    for (final line in description.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('조리법:')) {
        final stepsText = trimmed.substring('조리법:'.length).trim();
        final parts = stepsText.split(RegExp(r'\s*\d+\.\s+'));
        return parts.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final ingredients = _parseIngredients(recipe.description);
    final steps = _parseSteps(recipe.description);
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          const CartIconButton(),
          IconButton(
            icon: Icon(
              _isSaved == 1 ? Icons.bookmark : Icons.bookmark_outline,
              color: _isSaved == 1 ? Colors.amber : null,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YouTube 썸네일 (최상단, 전체 너비)
            if (recipe.youtubeUrl != null)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(recipe.youtubeUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Stack(
                  children: [
                    Builder(builder: (context) {
                      final videoId = Uri.tryParse(recipe.youtubeUrl!)
                          ?.queryParameters['v'];
                      final thumb = videoId != null
                          ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
                          : null;
                      return thumb != null
                          ? Image.network(thumb,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                    height: 220,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.play_circle_outline,
                                        size: 64, color: Colors.grey),
                                  ))
                          : Container(height: 220, color: Colors.grey[200]);
                    }),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.play_circle_filled,
                              color: Colors.red, size: 14),
                          const SizedBox(width: 4),
                          Text(recipe.youtubeTitle ?? 'YouTube',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // YouTube에서 보기 버튼
                  if (recipe.youtubeUrl != null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_filled,
                          color: Colors.white),
                      label: const Text('YouTube에서 영상 보기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () async {
                        final uri = Uri.tryParse(recipe.youtubeUrl!);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 필요 재료
                  if (ingredients.isNotEmpty) ...[
                    const Text('필요 재료',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: ingredients
                            .map((ing) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(ing,
                                            style: const TextStyle(
                                                fontSize: 14, height: 1.5)),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 조리법
                  if (steps.isNotEmpty) ...[
                    const Text('조리법',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...steps.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final step = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('$idx',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade100),
                                ),
                                child: Text(step,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.6)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
