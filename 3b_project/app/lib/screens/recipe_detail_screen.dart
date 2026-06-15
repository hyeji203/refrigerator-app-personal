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
  @override
  void initState() {
    super.initState();
    ApiService.dio
        .patch('/recipes/${widget.recipe.recipeId}/view')
        .catchError((_) {});
  }

  static ({String ingredients, String steps}) _parseRecipeDetail(
      String? description) {
    if (description == null || description.isEmpty) {
      return (ingredients: '', steps: '');
    }
    String ingredients = '';
    String steps = '';
    for (final line in description.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('주재료:')) {
        ingredients = trimmed.substring('주재료:'.length).trim();
      } else if (trimmed.startsWith('조리법:')) {
        String stepsText = trimmed.substring('조리법:'.length).trim();
        stepsText = stepsText.replaceAllMapped(
          RegExp(r'\s+(\d+)\.\s+'),
          (m) => '\n${m.group(1)}. ',
        );
        steps = stepsText.trim();
      }
    }
    return (ingredients: ingredients, steps: steps);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final parsed = _parseRecipeDetail(recipe.description);
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          const CartIconButton(),
          IconButton(
            icon: Icon(
              recipe.isSaved == 1 ? Icons.bookmark : Icons.bookmark_outline,
              color: recipe.isSaved == 1 ? Colors.amber : null,
            ),
            onPressed: () async {
              await ApiService.dio.patch('/recipes/${recipe.recipeId}/save');
              if (!mounted) return;
              Navigator.pop(context);
            },
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
                  if (parsed.ingredients.isNotEmpty) ...[
                    const Text('필요 재료',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        parsed.ingredients,
                        style: const TextStyle(
                            fontSize: 14, height: 1.6, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 조리법
                  if (parsed.steps.isNotEmpty) ...[
                    const Text('조리법',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        parsed.steps,
                        style: const TextStyle(
                            fontSize: 14, height: 1.8, color: Colors.black87),
                      ),
                    ),
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
