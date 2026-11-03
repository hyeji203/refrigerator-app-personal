import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/ingredient_service.dart';
import 'allergy_screen.dart';
import 'edit_profile_screen.dart';
import 'cart_screen.dart';
import 'onboarding_screen.dart';
import 'recipe_history_screen.dart';
import 'recipe_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onGoToFridge; // 냉장고 탭으로 이동
  const ProfileScreen({super.key, this.onGoToFridge});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  static const _green = Color(0xFF2E7D32);
  static const _sectionGap = Color(0xFFF3F4F3);

  // 나의 냉장고 요약 (불러오기 전/실패 시 null → '-' 표시)
  int? _ingredientCount;
  int? _expiringCount;
  int? _bookmarkCount;

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  Future<void> loadSummary() async {
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    try {
      final ingredients = await IngredientApiService.getIngredients(userId);
      final response = await ApiService.dio.get('/recipes/user/$userId');
      final List recipes = response.data;
      if (!mounted) return;
      setState(() {
        _ingredientCount = ingredients.length;
        _expiringCount =
            ingredients.where((i) => i.expiringSoon || i.expired).length;
        _bookmarkCount = recipes.where((r) => r['isSaved'] == 1).length;
      });
    } catch (_) {
      // 요약은 부가 정보라 실패해도 화면은 그대로 사용
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cartCount = context.watch<CartService>().unpurchasedCount;
    final name = (auth.username ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: RefreshIndicator(
        onRefresh: loadSummary,
        child: ListView(
          children: [
            // 프로필
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _green),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? '사용자' : name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (auth.loginId != null) '@${auth.loginId}',
                            if (auth.email != null) auth.email!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _push(const EditProfileScreen()),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text('수정'),
                  ),
                ],
              ),
            ),

            // 나의 냉장고 요약
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _stat('보관 중인 재료', _ingredientCount,
                        onTap: widget.onGoToFridge),
                    VerticalDivider(color: Colors.grey.shade300, width: 1),
                    _stat('유통기한 임박', _expiringCount,
                        highlight: (_expiringCount ?? 0) > 0,
                        onTap: widget.onGoToFridge),
                    VerticalDivider(color: Colors.grey.shade300, width: 1),
                    _stat('북마크 레시피', _bookmarkCount,
                        onTap: () =>
                            _push(const RecipeScreen(showOnlySaved: true))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle('나의 활동'),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text('장바구니'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cartCount > 0)
                    Text('$cartCount개',
                        style: const TextStyle(color: _green, fontSize: 13)),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _push(const CartScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('북마크한 레시피'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(const RecipeScreen(showOnlySaved: true)),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('레시피 기록'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(const RecipeHistoryScreen()),
            ),

            Container(height: 8, color: _sectionGap),
            _sectionTitle('설정'),
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: const Text('알레르기 관리'),
              subtitle: Text(
                (auth.allergies ?? '').trim().isEmpty
                    ? '등록하면 레시피 추천에서 제외돼요'
                    : auth.allergies!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(const AllergyScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('앱 사용법 다시 보기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const OnboardingScreen()),
              ),
            ),

            Container(height: 8, color: _sectionGap),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('로그아웃'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃할까요?'),
                    content: const Text('다시 이용하려면 아이디와 비밀번호를 입력해야 해요.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await auth.logout();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
      );

  Widget _stat(String label, int? value,
      {bool highlight = false, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              value?.toString() ?? '-',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: highlight ? Colors.deepOrange : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
