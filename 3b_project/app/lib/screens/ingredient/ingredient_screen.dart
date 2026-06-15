import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../models/ingredient.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../widgets/empty_state_widget.dart';
import 'widgets/expiry_notification_panel.dart';
import 'widgets/ingredient_action_dialog.dart';

class IngredientScreen extends StatefulWidget {
  const IngredientScreen({super.key});

  @override
  State<IngredientScreen> createState() => IngredientScreenState();
}

class IngredientScreenState extends State<IngredientScreen> {
  List<Ingredient> _ingredients = [];
  List<Ingredient> _expiringIngredients = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> loadIngredients() => _loadIngredients();

  Future<void> _loadIngredients() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        IngredientApiService.getIngredients(userId),
        IngredientApiService.getExpiringIngredients(userId),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw Exception('서버 응답 시간이 초과됐습니다. 서버가 실행 중인지 확인해주세요.'),
      );
      if (!mounted) return;
      setState(() {
        _ingredients = results[0];
        _expiringIngredients = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('식재료를 불러오는 중 오류: $e'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '재시도', onPressed: _loadIngredients),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IngredientActionDialog(onSaved: _loadIngredients),
    );
  }

  void _openEditDialog(Ingredient ingredient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IngredientActionDialog(
        ingredient: ingredient,
        onSaved: _loadIngredients,
      ),
    );
  }

  List<_IngredientGroup> get _groupedIngredients {
    final map = <String, List<Ingredient>>{};
    for (final ingredient in _ingredients) {
      final key = ingredient.ingredientName.trim().toLowerCase();
      map.putIfAbsent(key, () => []).add(ingredient);
    }
    return map.values.map((items) => _IngredientGroup(items)).toList();
  }

  void _openGroupDialog(_IngredientGroup group) {
    if (group.items.length == 1) {
      _openEditDialog(group.items.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                group.items.first.ingredientName,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...group.items.asMap().entries.map((entry) {
              final i = entry.key;
              final ingredient = entry.value;
              final qty = (ingredient.quantity != null &&
                      ingredient.quantity!.isNotEmpty)
                  ? ingredient.quantity!
                  : '수량 없음';
              final exp = ingredient.expiryDate != null
                  ? ingredient.expiryDate!
                  : '유통기한 없음';
              return ListTile(
                title: Text('항목 ${i + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('수량: $qty   유통기한: $exp'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openEditDialog(ingredient);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(ingredient);
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget? _buildGroupSubtitle(_IngredientGroup group) {
    final expiries = group.items
        .where((i) => i.expiryDate != null)
        .map((i) => i.expiryDate!)
        .toSet()
        .toList()
      ..sort();

    if (expiries.isEmpty) return null;
    return Text('유통기한: ${expiries.join(' · ')}');
  }

  static ({String emoji, Color bgColor}) _ingredientAppearance(String name) {
    if (name.contains('버섯')) return (emoji: '🍄', bgColor: Colors.brown[100]!);
    if (name.contains('파인애플'))
      return (emoji: '🍍', bgColor: Colors.yellow[50]!);
    if (name.contains('파파야')) return (emoji: '🍈', bgColor: Colors.orange[50]!);
    if (name.contains('고구마')) return (emoji: '🍠', bgColor: Colors.orange[50]!);
    if (name.contains('감자')) return (emoji: '🥔', bgColor: Colors.orange[50]!);
    if (name.contains('당근')) return (emoji: '🥕', bgColor: Colors.orange[50]!);
    if (name.contains('가지')) return (emoji: '🍆', bgColor: Colors.purple[50]!);
    if (name.contains('옥수수')) return (emoji: '🌽', bgColor: Colors.yellow[50]!);
    if (name.contains('파프리카') || name.contains('피망'))
      return (emoji: '🫑', bgColor: Colors.green[50]!);
    if (name.contains('고추')) return (emoji: '🌶️', bgColor: Colors.red[50]!);
    if (name.contains('오이')) return (emoji: '🥒', bgColor: Colors.green[50]!);
    if (name.contains('브로콜리')) return (emoji: '🥦', bgColor: Colors.green[50]!);
    if (name.contains('마늘')) return (emoji: '🧄', bgColor: Colors.grey[100]!);
    if (name.contains('양파')) return (emoji: '🧅', bgColor: Colors.yellow[50]!);
    if (name.contains('땅콩')) return (emoji: '🥜', bgColor: Colors.brown[50]!);
    if (name.contains('밤')) return (emoji: '🌰', bgColor: Colors.brown[50]!);
    if (name.contains('생강')) return (emoji: '🧄', bgColor: Colors.yellow[50]!);
    if (name.contains('무') || name.contains('순무') || name.contains('비트'))
      return (emoji: '🥕', bgColor: Colors.orange[50]!);
    if (name.contains('두부')) return (emoji: '🫘', bgColor: Colors.grey[50]!);
    if (name.contains('콩나물') || name.contains('숙주'))
      return (emoji: '🌱', bgColor: Colors.green[50]!);
    if (name.contains('콩')) return (emoji: '🫘', bgColor: Colors.green[50]!);
    if (name.contains('팥')) return (emoji: '🫘', bgColor: Colors.red[50]!);
    const leafyVegs = [
      '상추',
      '배추',
      '시금치',
      '깻잎',
      '부추',
      '양배추',
      '파슬리',
      '셀러리',
      '아스파라거스',
      '열무',
      '치커리',
      '케일',
      '루꼴라'
    ];
    if (leafyVegs.any(name.contains))
      return (emoji: '🥬', bgColor: Colors.green[50]!);
    if (name.contains('파')) return (emoji: '🥬', bgColor: Colors.green[50]!);
    if (name.contains('포도')) return (emoji: '🍇', bgColor: Colors.purple[50]!);
    if (name.contains('멜론')) return (emoji: '🍈', bgColor: Colors.green[50]!);
    if (name.contains('수박')) return (emoji: '🍉', bgColor: Colors.green[50]!);
    if (name.contains('귤') || name.contains('오렌지') || name.contains('만다린'))
      return (emoji: '🍊', bgColor: Colors.orange[50]!);
    if (name.contains('레몬') || name.contains('라임'))
      return (emoji: '🍋', bgColor: Colors.yellow[50]!);
    if (name.contains('바나나')) return (emoji: '🍌', bgColor: Colors.yellow[50]!);
    if (name.contains('망고')) return (emoji: '🥭', bgColor: Colors.orange[50]!);
    if (name.contains('사과')) return (emoji: '🍎', bgColor: Colors.red[50]!);
    if (name.contains('배')) return (emoji: '🍐', bgColor: Colors.green[50]!);
    if (name.contains('복숭아')) return (emoji: '🍑', bgColor: Colors.orange[50]!);
    if (name.contains('자두')) return (emoji: '🍑', bgColor: Colors.purple[50]!);
    if (name.contains('체리')) return (emoji: '🍒', bgColor: Colors.red[50]!);
    if (name.contains('딸기') || name.contains('라즈베리') || name.contains('산딸기'))
      return (emoji: '🍓', bgColor: Colors.red[50]!);
    if (name.contains('블루베리'))
      return (emoji: '🫐', bgColor: Colors.indigo[50]!);
    if (name.contains('키위')) return (emoji: '🥝', bgColor: Colors.green[50]!);
    if (name.contains('토마토')) return (emoji: '🍅', bgColor: Colors.red[50]!);
    if (name.contains('올리브오일'))
      return (emoji: '🫙', bgColor: Colors.green[50]!);
    if (name.contains('올리브')) return (emoji: '🫒', bgColor: Colors.green[50]!);
    if (name.contains('코코넛')) return (emoji: '🥥', bgColor: Colors.brown[50]!);
    if (name.contains('아보카도')) return (emoji: '🥑', bgColor: Colors.green[50]!);
    if (name.contains('무화과')) return (emoji: '🍈', bgColor: Colors.purple[50]!);
    if (name.contains('석류')) return (emoji: '🍎', bgColor: Colors.red[50]!);
    if (name.contains('베이컨')) return (emoji: '🥓', bgColor: Colors.red[50]!);
    if (name.contains('소시지') || name.contains('핫도그') || name.contains('비엔나'))
      return (emoji: '🌭', bgColor: Colors.red[50]!);
    if (name.contains('닭') || name.contains('치킨'))
      return (emoji: '🍗', bgColor: Colors.orange[50]!);
    if (name.contains('햄')) return (emoji: '🥩', bgColor: Colors.red[50]!);
    if (name.contains('양고기')) return (emoji: '🍖', bgColor: Colors.red[50]!);
    const meats = [
      '소고기',
      '한우',
      '돼지',
      '삼겹살',
      '갈비',
      '등심',
      '안심',
      '목살',
      '차돌',
      '육회'
    ];
    if (meats.any(name.contains))
      return (emoji: '🥩', bgColor: Colors.red[50]!);
    if (name.contains('새우튀김'))
      return (emoji: '🍤', bgColor: Colors.orange[50]!);
    if (name.contains('새우')) return (emoji: '🦐', bgColor: Colors.pink[50]!);
    if (name.contains('오징어') || name.contains('낙지') || name.contains('문어'))
      return (emoji: '🦑', bgColor: Colors.purple[50]!);
    if (name.contains('꽃게') || name.contains('대게') || name.contains('게'))
      return (emoji: '🦀', bgColor: Colors.orange[50]!);
    if (name.contains('가재') || name.contains('랍스터'))
      return (emoji: '🦞', bgColor: Colors.red[50]!);
    if (name.contains('굴') ||
        name.contains('조개') ||
        name.contains('바지락') ||
        name.contains('홍합') ||
        name.contains('전복') ||
        name.contains('가리비')) return (emoji: '🦪', bgColor: Colors.blue[50]!);
    if (name.contains('어묵') || name.contains('오뎅'))
      return (emoji: '🍥', bgColor: Colors.pink[50]!);
    const fish = [
      '연어',
      '참치',
      '고등어',
      '꽁치',
      '갈치',
      '명태',
      '대구',
      '광어',
      '도미',
      '방어',
      '삼치',
      '장어',
      '멸치'
    ];
    if (fish.any(name.contains))
      return (emoji: '🐟', bgColor: Colors.blue[50]!);
    if (name.contains('달걀') || name.contains('계란'))
      return (emoji: '🥚', bgColor: Colors.yellow[50]!);
    if (name.contains('우유')) return (emoji: '🥛', bgColor: Colors.blue[50]!);
    if (name.contains('치즈')) return (emoji: '🧀', bgColor: Colors.yellow[50]!);
    if (name.contains('버터')) return (emoji: '🧈', bgColor: Colors.yellow[50]!);
    if (name.contains('요거트') || name.contains('요구르트'))
      return (emoji: '🥛', bgColor: Colors.blue[50]!);
    if (name.contains('크림')) return (emoji: '🧈', bgColor: Colors.yellow[50]!);
    if (name.contains('만두') || name.contains('교자'))
      return (emoji: '🥟', bgColor: Colors.orange[50]!);
    if (name.contains('떡')) return (emoji: '🍡', bgColor: Colors.pink[50]!);
    if (name.contains('라면') ||
        name.contains('국수') ||
        name.contains('우동') ||
        name.contains('소바')) return (emoji: '🍜', bgColor: Colors.orange[50]!);
    if (name.contains('파스타') || name.contains('스파게티') || name.contains('펜네'))
      return (emoji: '🍝', bgColor: Colors.orange[50]!);
    if (name.contains('크루아상'))
      return (emoji: '🥐', bgColor: Colors.orange[50]!);
    if (name.contains('바게트')) return (emoji: '🥖', bgColor: Colors.orange[50]!);
    if (name.contains('베이글')) return (emoji: '🥯', bgColor: Colors.orange[50]!);
    if (name.contains('팬케이크'))
      return (emoji: '🥞', bgColor: Colors.orange[50]!);
    if (name.contains('와플')) return (emoji: '🧇', bgColor: Colors.orange[50]!);
    if (name.contains('빵')) return (emoji: '🍞', bgColor: Colors.orange[50]!);
    if (name.contains('쌀') ||
        name.contains('밥') ||
        name.contains('현미') ||
        name.contains('보리') ||
        name.contains('귀리')) return (emoji: '🍚', bgColor: Colors.grey[50]!);
    if (name.contains('밀가루')) return (emoji: '🌾', bgColor: Colors.amber[50]!);
    if (name.contains('소금')) return (emoji: '🧂', bgColor: Colors.grey[50]!);
    if (name.contains('꿀')) return (emoji: '🍯', bgColor: Colors.amber[50]!);
    if (name.contains('설탕') || name.contains('시럽'))
      return (emoji: '🍯', bgColor: Colors.amber[50]!);
    const sauces = [
      '간장',
      '된장',
      '고추장',
      '쌈장',
      '케첩',
      '마요네즈',
      '참기름',
      '들기름',
      '식초',
      '굴소스'
    ];
    if (sauces.any(name.contains))
      return (emoji: '🫙', bgColor: Colors.grey[50]!);
    if (name.contains('커피') || name.contains('에스프레소') || name.contains('라떼'))
      return (emoji: '☕', bgColor: Colors.brown[50]!);
    if (name.endsWith('차') || name == '차')
      return (emoji: '🍵', bgColor: Colors.green[50]!);
    if (name.contains('주스')) return (emoji: '🧃', bgColor: Colors.orange[50]!);
    if (name.contains('맥주')) return (emoji: '🍺', bgColor: Colors.amber[50]!);
    if (name.contains('와인')) return (emoji: '🍷', bgColor: Colors.red[50]!);
    if (name.contains('버블티') || name.contains('밀크티'))
      return (emoji: '🧋', bgColor: Colors.brown[50]!);
    if (name.contains('탄산') || name.contains('사이다') || name.contains('콜라'))
      return (emoji: '🥤', bgColor: Colors.blue[50]!);
    if (name.contains('막걸리') || name.contains('소주') || name.contains('사케'))
      return (emoji: '🍶', bgColor: Colors.grey[50]!);
    if (name.contains('아이스크림')) return (emoji: '🍨', bgColor: Colors.blue[50]!);
    if (name.contains('케이크')) return (emoji: '🍰', bgColor: Colors.pink[50]!);
    if (name.contains('쿠키') || name.contains('비스킷'))
      return (emoji: '🍪', bgColor: Colors.orange[50]!);
    if (name.contains('초콜릿') || name.contains('초코'))
      return (emoji: '🍫', bgColor: Colors.brown[50]!);
    if (name.contains('사탕') || name.contains('캔디'))
      return (emoji: '🍬', bgColor: Colors.pink[50]!);
    if (name.contains('팝콘')) return (emoji: '🍿', bgColor: Colors.yellow[50]!);
    if (name.contains('도넛')) return (emoji: '🍩', bgColor: Colors.pink[50]!);
    if (name.contains('푸딩')) return (emoji: '🍮', bgColor: Colors.amber[50]!);
    if (name.contains('마카롱') || name.contains('컵케이크'))
      return (emoji: '🧁', bgColor: Colors.pink[50]!);
    if (name.contains('파이')) return (emoji: '🥧', bgColor: Colors.orange[50]!);
    return (emoji: '🍽️', bgColor: Colors.green[100]!);
  }

  Future<void> _confirmDelete(Ingredient ingredient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${ingredient.ingredientName}을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await IngredientApiService.deleteIngredient(ingredient.userIngredientId);
      _loadIngredients();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 냉장고'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () =>
                    ExpiryNotificationPanel.show(context, _expiringIngredients),
                tooltip: '유통기한 알림',
              ),
              if (_expiringIngredients.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _expiringIngredients.length > 9
                            ? '9+'
                            : '${_expiringIngredients.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIngredients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ingredients.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.kitchen_outlined,
                  title: '냉장고가 비어있어요!',
                  subtitle: '연필 버튼으로 재료를 추가하거나\n카메라로 스캔해보세요',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _groupedIngredients.length,
                  itemBuilder: (context, index) {
                    final group = _groupedIngredients[index];
                    final style =
                        _ingredientAppearance(group.items.first.ingredientName);
                    return Slidable(
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => _openGroupDialog(group),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            icon: Icons.edit,
                            label: '수정',
                          ),
                          SlidableAction(
                            onPressed: (_) => group.items.length == 1
                                ? _confirmDelete(group.items.first)
                                : _openGroupDialog(group),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: '삭제',
                          ),
                        ],
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          onTap: () => _openGroupDialog(group),
                          leading: CircleAvatar(
                            backgroundColor: style.bgColor,
                            child: Text(style.emoji,
                                style: const TextStyle(fontSize: 20)),
                          ),
                          title: Row(
                            children: [
                              Text(group.items.first.ingredientName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              if (group.items.length > 1) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${group.items.length}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: _buildGroupSubtitle(group),
                          trailing: group.hasExpired
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('만료됨',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                )
                              : group.hasExpiringSoon
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text('곧 만료',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11)),
                                    )
                                  : null,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _IngredientGroup {
  final List<Ingredient> items;
  _IngredientGroup(this.items);

  bool get hasExpired => items.any((i) => i.expired);
  bool get hasExpiringSoon => items.any((i) => i.expiringSoon);
}
