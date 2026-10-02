import '../models/ingredient.dart';

// 레시피 재료 줄("다진 마늘 1큰술")을 재료명/분량으로 나누고
// 냉장고 보유 여부를 판단하는 유틸.

enum IngredientStock { owned, expired, missing, seasoning }

class RecipeIngredientLine {
  final String name;
  final String? amount;
  final IngredientStock stock;

  const RecipeIngredientLine(this.name, this.amount, this.stock);

  /// 장바구니에 담을 대상인지 (보유 중이 아닌 재료)
  bool get needsBuying =>
      stock == IngredientStock.missing || stock == IngredientStock.expired;
}

// 냉장고에 따로 등록하지 않는 기본 양념 (부족으로 표시하지 않음)
const Set<String> _seasonings = {
  '소금', '꽃소금', '천일염', '후추', '후춧가루', '설탕', '간장', '진간장', '국간장', '양조간장',
  '참기름', '들기름', '식용유', '올리브유', '포도씨유', '물', '깨', '통깨', '참깨', '깨소금',
  '식초', '맛술', '미림', '청주', '물엿', '올리고당', '조청', '고춧가루', '고추장', '된장',
  '다시다', '굴소스', '액젓', '멸치액젓', '까나리액젓', '케첩', '마요네즈', '버터',
};

// 분량을 나타내는 말 (숫자가 없어도 분량으로 취급)
final RegExp _amountWord = RegExp(
    r'^(약간|적당량|조금|한줌|한 줌|반|반개|반쪽|넉넉히|취향껏|톡톡|한꼬집|꼬집)');

/// "다진 마늘 1큰술" → ("다진 마늘", "1큰술")
({String name, String? amount}) splitNameAmount(String line) {
  final text = line.trim();
  // 첫 숫자 또는 분량 단어가 나오는 위치에서 분리
  final tokens = text.split(RegExp(r'\s+'));
  for (var i = 1; i < tokens.length; i++) {
    final t = tokens[i];
    if (RegExp(r'^[\d½⅓¼]').hasMatch(t) || _amountWord.hasMatch(t)) {
      return (
        name: tokens.sublist(0, i).join(' '),
        amount: tokens.sublist(i).join(' '),
      );
    }
  }
  // "양파1개"처럼 붙어 있는 경우
  final m = RegExp(r'^(\D+?)(\d.*)$').firstMatch(text);
  if (m != null) return (name: m.group(1)!.trim(), amount: m.group(2)!.trim());
  return (name: text, amount: null);
}

String _compact(String s) =>
    s.replaceAll(RegExp(r'\s+|\(.*?\)'), '').toLowerCase();

bool _isSeasoning(String name) {
  final c = _compact(name);
  // "진한 간장"처럼 수식어가 붙은 경우도 양념으로 (한 글자 양념 물·깨는 정확히 일치만: 해물 ≠ 물)
  return _seasonings.contains(c) ||
      _seasonings.any(
          (s) => s.length > 1 && c.endsWith(s) && c.length <= s.length + 2);
}

/// 레시피 재료명과 냉장고 재료명이 같은 재료인지 (서로 포함 관계)
bool _sameIngredient(String recipeName, String fridgeName) {
  final a = _compact(recipeName);
  final b = _compact(fridgeName);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  // 한 글자 이름(파, 무 등)은 수식어만 뗀 뒤 정확히 일치할 때만 인정
  // (대파 ↔ 파 O, 양파 ↔ 파 X)
  if (a.length == 1 || b.length == 1) {
    return _stripModifier(a) == _stripModifier(b);
  }
  return a.contains(b) || b.contains(a);
}

const _modifiers = ['다진', '냉동', '대', '쪽', '실', '깐', '생', '통', '신'];

String _stripModifier(String s) {
  for (final m in _modifiers) {
    if (s.length > m.length && s.startsWith(m)) return s.substring(m.length);
  }
  return s;
}

RecipeIngredientLine classifyIngredient(String line, List<Ingredient> fridge) {
  final parts = splitNameAmount(line);
  final matches =
      fridge.where((f) => _sameIngredient(parts.name, f.ingredientName));
  IngredientStock stock;
  if (matches.any((f) => !f.expired)) {
    stock = IngredientStock.owned;
  } else if (matches.isNotEmpty) {
    stock = IngredientStock.expired;
  } else if (_isSeasoning(parts.name)) {
    stock = IngredientStock.seasoning;
  } else {
    stock = IngredientStock.missing;
  }
  return RecipeIngredientLine(parts.name, parts.amount, stock);
}
