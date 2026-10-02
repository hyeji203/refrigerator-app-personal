// 알레르기 유발 재료 목록과 레시피 재료 매칭 유틸.
// 서버의 AllergenMatcher와 같은 키워드 목록을 유지해야 한다.

/// 칩으로 보여줄 대표 알레르기 항목 → 해당 재료로 판단할 키워드
const Map<String, List<String>> allergenKeywords = {
  '우유': ['우유', '치즈', '버터', '생크림', '요거트', '요구르트', '연유', '크림', '분유'],
  '계란': ['계란', '달걀', '메추리알', '마요네즈'],
  '밀': ['밀가루', '밀', '빵', '국수', '라면', '파스타', '스파게티', '부침가루', '튀김가루', '빵가루', '만두피', '우동', '칼국수', '수제비', '또띠아'],
  '메밀': ['메밀'],
  '대두': ['대두', '콩', '두부', '된장', '간장', '두유', '청국장', '유부'],
  '땅콩': ['땅콩'],
  '견과류': ['견과', '호두', '아몬드', '잣', '캐슈넛', '피스타치오', '헤이즐넛', '마카다미아'],
  '갑각류': ['새우', '게', '꽃게', '대게', '킹크랩', '크랩', '랍스터', '가재', '게맛살'],
  '조개류': ['조개', '굴', '홍합', '전복', '바지락', '가리비', '꼬막', '재첩'],
  '오징어': ['오징어', '한치'],
  '생선': ['생선', '고등어', '연어', '참치', '멸치', '명태', '동태', '대구', '갈치', '꽁치', '삼치', '황태', '북어'],
  '복숭아': ['복숭아'],
  '토마토': ['토마토', '케첩'],
  '돼지고기': ['돼지고기', '삼겹살', '목살', '베이컨', '햄', '소시지', '스팸'],
  '쇠고기': ['쇠고기', '소고기', '차돌', '양지', '사태', '우삼겹'],
  '닭고기': ['닭', '치킨'],
};

/// 저장 문자열("우유, 계란") → 목록
List<String> parseAllergies(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();
}

/// 목록 → 저장 문자열
String joinAllergies(List<String> allergies) => allergies.join(', ');

/// 사용자가 입력한 알레르기 이름을 대표 항목으로 정규화 (예: 달걀 → 계란)
String normalizeAllergen(String input) {
  final name = input.trim();
  if (allergenKeywords.containsKey(name)) return name;
  for (final entry in allergenKeywords.entries) {
    if (entry.value.contains(name)) return entry.key;
  }
  return name;
}

List<String> _keywordsFor(String allergen) =>
    allergenKeywords[allergen] ?? [allergen];

/// 재료 한 줄(예: "모짜렐라 치즈 100g")에 포함된 알레르기 항목
List<String> matchAllergens(String ingredient, List<String> allergies) {
  final text = ingredient.replaceAll(' ', '');
  final matched = <String>[];
  for (final allergen in allergies) {
    final hit = _keywordsFor(allergen).any((kw) {
      final k = kw.replaceAll(' ', '');
      if (k.isEmpty) return false;
      // 한 글자 키워드(게, 밀, 콩, 굴 등)는 오탐을 줄이기 위해 재료명 시작에서만 매칭
      return k.length == 1 ? text.startsWith(k) : text.contains(k);
    });
    if (hit) matched.add(allergen);
  }
  return matched;
}

/// 레시피 재료 목록 전체에서 포함된 알레르기 항목 (중복 제거)
List<String> matchRecipeAllergens(
    List<String> ingredients, List<String> allergies) {
  if (allergies.isEmpty) return [];
  final result = <String>{};
  for (final ing in ingredients) {
    result.addAll(matchAllergens(ing, allergies));
  }
  return result.toList();
}
