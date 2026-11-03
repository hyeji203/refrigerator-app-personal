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
  late Recipe _recipe;

  // 영상 내용으로 레시피를 정리하는 중인지
  bool _syncingVideo = false;

  // 냉장고 재료 (보유/부족 판단용). null = 아직 불러오는 중
  List<Ingredient>? _fridge;
  bool _fridgeError = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.recipe.isSaved;
    _recipe = widget.recipe;
    ApiService.dio
        .patch('/recipes/${widget.recipe.recipeId}/view')
        .catchError((_) {});
    _loadFridge();
    _syncWithVideo();
  }

  // 영상이 있는데 아직 영상 기준으로 정리되지 않았으면 서버에 정리 요청
  Future<void> _syncWithVideo() async {
    if (_recipe.youtubeUrl == null || _recipe.isFromVideo) return;
    setState(() => _syncingVideo = true);
    try {
      final res = await ApiService.dioLong
          .post('/recipes/${_recipe.recipeId}/video-recipe');
      if (mounted) {
        setState(() => _recipe = Recipe.fromJson(res.data));
      }
    } catch (_) {
      // 실패 시 기존 AI 레시피를 그대로 보여줌
    } finally {
      if (mounted) setState(() => _syncingVideo = false);
    }
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
    // 레시피 분량(1큰술, 1/2개 등)은 요리에 쓰는 양이라 장보기 수량으로 맞지 않음 → 이름만 담기
    context.read<CartService>().addItem(line.name);
    _showCartSnack("'${line.name}'을(를) 장바구니에 담았어요.");
  }

  // 부족한 재료 일괄 담기 (알레르기 재료는 제외)
  void _addMissingToCart(List<RecipeIngredientLine> toAdd, int skippedAllergy) {
    context.read<CartService>().addItems(
        toAdd.map((l) => CartItem(name: l.name)).toList());
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
      // 더 담을 재료 없음 → 상태는 안내 줄로, 이동은 별도 버튼으로 분리
      final skippedAllergy = allergyIdx
          .where((i) => !cart.hasItem(lines[i].name))
          .map((i) => lines[i].name)
          .toList();
      final anyInCart = missingIdx.any((i) => cart.hasItem(lines[i].name));

      final IconData icon;
      final Color color;
      final String message;
      if (skippedAllergy.isEmpty) {
        icon = Icons.check_circle;
        color = Colors.green.shade800;
        message = '부족한 재료를 모두 담았어요';
      } else {
        icon = Icons.warning_amber_rounded;
        color = Colors.red.shade700;
        message = '알레르기 재료(${skippedAllergy.join(', ')})는 담지 않았어요';
      }

      return Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.bold)),
          ),
          if (anyInCart)
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CartScreen())),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('장바구니 보기'),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
        ],
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
    final recipe = _recipe;
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
            // YouTube 썸네일 (최상단, 전체 너비) - 누르면 영상 열기 (별도 버튼 없음)
            if (recipe.youtubeUrl != null)
              Semantics(
                button: true,
                label: '참고 영상 보기, 유튜브에서 열림',
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
                    // 누를 때 눌림 효과가 보이도록 썸네일 위에 InkWell
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final uri = Uri.tryParse(recipe.youtubeUrl!);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // 레시피 출처 안내 (썸네일 바로 아래)
            if (recipe.youtubeUrl != null && !_syncingVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.info_outline,
                          size: 14, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        recipe.isFromVideo
                            ? '아래 재료·조리법은 위 영상 내용을 바탕으로 정리했습니다. 보유·부족은 내 냉장고 기준입니다.'
                            : '영상 내용을 불러오지 못해 내 냉장고 재료 기반으로 AI가 생성한 레시피를 보여드려요. 영상과 다를 수 있습니다.',
                        style: TextStyle(
                            fontSize: 12, height: 1.4, color: Colors.grey[600]),
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
                  // 영상 내용 정리 중: 바뀌기 전 레시피가 잠깐 보였다 바뀌지 않도록 로딩만 표시
                  if (_syncingVideo)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 14),
                            Text('영상에서 재료와 조리법을 정리하는 중...',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[700])),
                            const SizedBox(height: 4),
                            Text('처음 한 번만 걸려요. 잠시만 기다려 주세요.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    )
                  else ...[
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
