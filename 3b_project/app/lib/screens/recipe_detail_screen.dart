import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/ingredient_service.dart';
import '../utils/allergy.dart';
import '../utils/recipe_ingredient.dart';
import 'cart_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _isSaved;

  // 냉장고 재료 (보유/부족 판단용). null = 아직 불러오는 중
  List<Ingredient>? _fridge;
  bool _fridgeError = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.recipe.isSaved;
    ApiService.dio
        .patch('/recipes/${widget.recipe.recipeId}/view')
        .catchError((_) {});
    _loadFridge();
  }

  Future<void> _loadFridge() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() {
      _fridge = null;
      _fridgeError = false;
    });
    try {
      final list = await IngredientApiService.getIngredients(userId);
      if (mounted) setState(() => _fridge = list);
    } catch (_) {
      if (mounted) setState(() => _fridgeError = true);
    }
  }

  void _showCartSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: '장바구니 보기',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CartScreen())),
        ),
      ));
  }

  void _addToCart(RecipeIngredientLine line) {
    context.read<CartService>().addItem(line.name, amount: line.amount);
    _showCartSnack("'${line.name}'을(를) 장바구니에 담았어요.");
  }

  // 부족한 재료 일괄 담기 (알레르기 재료는 제외)
  void _addMissingToCart(List<RecipeIngredientLine> toAdd, int skippedAllergy) {
    context.read<CartService>().addItems(
        toAdd.map((l) => CartItem(name: l.name, amount: l.amount)).toList());
    _showCartSnack(skippedAllergy > 0
        ? '부족한 재료 ${toAdd.length}개를 담았어요. (알레르기 재료 $skippedAllergy개 제외)'
        : '부족한 재료 ${toAdd.length}개를 장바구니에 담았어요.');
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

  // ──────────────────── 필요 재료 ────────────────────

  Widget _buildIngredientSection(
      List<String> ingredients, List<String> allergies) {
    final cart = context.watch<CartService>();
    final fridge = _fridge;
    final lines = fridge == null
        ? null
        : ingredients.map((i) => classifyIngredient(i, fridge)).toList();

    final ownedCount =
        lines?.where((l) => l.stock == IngredientStock.owned).length ?? 0;
    final missingIdx = <int>[
      for (var i = 0; i < (lines?.length ?? 0); i++)
        if (lines![i].needsBuying) i
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('필요 재료',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (lines != null)
              Text('보유 $ownedCount · 부족 ${missingIdx.length}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              for (var i = 0; i < ingredients.length; i++)
                _buildIngredientRow(ingredients[i], lines?[i],
                    matchAllergens(ingredients[i], allergies), cart),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildCartAction(ingredients, lines, missingIdx, allergies, cart),
      ],
    );
  }

  Widget _buildIngredientRow(String raw, RecipeIngredientLine? line,
      List<String> allergyHit, CartService cart) {
    // 상태: 아이콘 + 글자로 함께 표시 (색만으로 구분하지 않음)
    IconData icon;
    Color color;
    String? label;
    switch (line?.stock) {
      case IngredientStock.owned:
        icon = Icons.check_circle;
        color = Colors.green.shade700;
        label = '보유';
      case IngredientStock.expired:
        icon = Icons.history_toggle_off;
        color = Colors.deepOrange;
        label = '기한 지남';
      case IngredientStock.missing:
        icon = Icons.error_outline;
        color = Colors.deepOrange;
        label = '부족';
      case IngredientStock.seasoning:
        icon = Icons.circle_outlined;
        color = Colors.grey.shade600;
        label = '양념';
      case null:
        icon = Icons.circle;
        color = Colors.deepOrange;
        label = null;
    }
    if (allergyHit.isNotEmpty) {
      icon = Icons.warning_amber_rounded;
      color = Colors.red.shade700;
    }

    final canBuy = line != null && line.stock != IngredientStock.owned;
    final inCart = line != null && cart.hasItem(line.name);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Icon(icon, size: line == null ? 8 : 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: line?.name ?? raw,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: allergyHit.isNotEmpty ? Colors.red[800] : null,
                  ),
                ),
                if (line?.amount != null)
                  TextSpan(
                      text: '  ${line!.amount}',
                      style: TextStyle(color: Colors.grey[700])),
                if (allergyHit.isNotEmpty)
                  TextSpan(
                    text: '\n${allergyHit.join(', ')} 알레르기',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold),
                  ),
              ]),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
          if (canBuy)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: inCart ? '장바구니에 있음' : '장바구니에 담기',
              icon: Icon(
                inCart ? Icons.shopping_cart : Icons.add_shopping_cart,
                size: 20,
                color: inCart
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
              onPressed: inCart ? null : () => _addToCart(line),
            )
          else if (line != null)
            const SizedBox(width: 40), // 버튼 자리 맞춤
        ],
      ),
    );
  }

  Widget _buildCartAction(List<String> ingredients,
      List<RecipeIngredientLine>? lines, List<int> missingIdx,
      List<String> allergies, CartService cart) {
    if (_fridgeError) {
      return Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text('냉장고 정보를 불러오지 못해 보유 여부를 표시하지 못했어요.',
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          TextButton(onPressed: _loadFridge, child: const Text('다시 시도')),
        ],
      );
    }
    if (lines == null) {
      return Row(
        children: [
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('내 냉장고 재료와 비교하는 중...',
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      );
    }
    if (missingIdx.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text('필요한 재료가 냉장고에 모두 있어요!',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }

    // 알레르기 재료와 이미 담은 재료는 일괄 담기에서 제외
    final allergyIdx = missingIdx
        .where((i) => matchAllergens(ingredients[i], allergies).isNotEmpty)
        .toList();
    final toAdd = missingIdx
        .where((i) => !allergyIdx.contains(i) && !cart.hasItem(lines[i].name))
        .map((i) => lines[i])
        .toList();

    if (toAdd.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.shopping_cart),
          label: const Text('부족한 재료를 장바구니에 담았어요'),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CartScreen())),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48)),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_shopping_cart),
        label: Text('부족한 재료 ${toAdd.length}개 장바구니에 담기'),
        onPressed: () => _addMissingToCart(toAdd, allergyIdx.length),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final ingredients = recipe.ingredientLines;
    final steps = _parseSteps(recipe.description);
    final allergies = parseAllergies(context.watch<AuthService>().allergies);
    final recipeAllergens = matchRecipeAllergens(ingredients, allergies);
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
                  // 알레르기 경고 (가장 먼저 보이도록 최상단)
                  if (recipeAllergens.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '알레르기 주의: ${recipeAllergens.join(', ')}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[800]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '등록한 알레르기 재료가 들어 있어요. 아래 ⚠ 표시된 재료를 빼거나 다른 재료로 바꿔 주세요.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.red[800]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // YouTube에서 보기 버튼
                  if (recipe.youtubeUrl != null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_filled,
                          color: Colors.white),
                      label: const Text('같은 요리 참고 영상 보기'),
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.orange),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '아래 재료·조리법은 내 냉장고 재료 기반으로 AI가 맞춤 생성한 것입니다. 영상의 재료와 다를 수 있습니다.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 필요 재료 (보유/부족 표시 + 장바구니 담기)
                  if (ingredients.isNotEmpty) ...[
                    _buildIngredientSection(ingredients, allergies),
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
