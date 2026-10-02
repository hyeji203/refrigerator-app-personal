package com.refrigerator.app.service;

import java.util.*;

/**
 * 알레르기 항목 → 재료 키워드 매칭.
 * Flutter의 app/lib/utils/allergy.dart 와 같은 키워드 목록을 유지해야 한다.
 */
public final class AllergenMatcher {

    private static final Map<String, List<String>> KEYWORDS = new LinkedHashMap<>();

    static {
        KEYWORDS.put("우유", List.of("우유", "치즈", "버터", "생크림", "요거트", "요구르트", "연유", "크림", "분유"));
        KEYWORDS.put("계란", List.of("계란", "달걀", "메추리알", "마요네즈"));
        KEYWORDS.put("밀", List.of("밀가루", "밀", "빵", "국수", "라면", "파스타", "스파게티", "부침가루", "튀김가루", "빵가루", "만두피", "우동", "칼국수", "수제비", "또띠아"));
        KEYWORDS.put("메밀", List.of("메밀"));
        KEYWORDS.put("대두", List.of("대두", "콩", "두부", "된장", "간장", "두유", "청국장", "유부"));
        KEYWORDS.put("땅콩", List.of("땅콩"));
        KEYWORDS.put("견과류", List.of("견과", "호두", "아몬드", "잣", "캐슈넛", "피스타치오", "헤이즐넛", "마카다미아"));
        KEYWORDS.put("갑각류", List.of("새우", "게", "꽃게", "대게", "킹크랩", "크랩", "랍스터", "가재", "게맛살"));
        KEYWORDS.put("조개류", List.of("조개", "굴", "홍합", "전복", "바지락", "가리비", "꼬막", "재첩"));
        KEYWORDS.put("오징어", List.of("오징어", "한치"));
        KEYWORDS.put("생선", List.of("생선", "고등어", "연어", "참치", "멸치", "명태", "동태", "대구", "갈치", "꽁치", "삼치", "황태", "북어"));
        KEYWORDS.put("복숭아", List.of("복숭아"));
        KEYWORDS.put("토마토", List.of("토마토", "케첩"));
        KEYWORDS.put("돼지고기", List.of("돼지고기", "삼겹살", "목살", "베이컨", "햄", "소시지", "스팸"));
        KEYWORDS.put("쇠고기", List.of("쇠고기", "소고기", "차돌", "양지", "사태", "우삼겹"));
        KEYWORDS.put("닭고기", List.of("닭", "치킨"));
    }

    private AllergenMatcher() {}

    private static List<String> keywordsFor(String allergen) {
        return KEYWORDS.getOrDefault(allergen, List.of(allergen));
    }

    /** 재료 한 개(예: "모짜렐라 치즈 100g")에 포함된 알레르기 항목 */
    public static List<String> match(String ingredient, Collection<String> allergens) {
        String text = ingredient.replace(" ", "");
        List<String> matched = new ArrayList<>();
        for (String allergen : allergens) {
            for (String kw : keywordsFor(allergen)) {
                String k = kw.replace(" ", "");
                if (k.isEmpty()) continue;
                // 한 글자 키워드(게, 밀, 콩, 굴 등)는 오탐을 줄이기 위해 재료명 시작에서만 매칭
                boolean hit = k.length() == 1 ? text.startsWith(k) : text.contains(k);
                if (hit) {
                    matched.add(allergen);
                    break;
                }
            }
        }
        return matched;
    }

    /** "주재료: a, b, c" 형식 줄에서 알레르기 재료가 하나라도 있는지 */
    public static boolean containsAny(String ingredientLine, Collection<String> allergens) {
        if (allergens.isEmpty() || ingredientLine == null) return false;
        String body = ingredientLine.replaceFirst("^주재료:", "");
        for (String item : body.split(",")) {
            if (!match(item.trim(), allergens).isEmpty()) return true;
        }
        return false;
    }

    /** Gemini 프롬프트용: "우유(치즈, 버터 ...), 계란(달걀 ...)" */
    public static String describeForPrompt(Collection<String> allergens) {
        List<String> parts = new ArrayList<>();
        for (String allergen : allergens) {
            List<String> kws = new ArrayList<>(keywordsFor(allergen));
            kws.remove(allergen);
            parts.add(kws.isEmpty() ? allergen : allergen + "(" + String.join(", ", kws) + " 등)");
        }
        return String.join(", ", parts);
    }
}
