package com.refrigerator.app.service;

import com.refrigerator.app.dto.RecipeResponseDto;
import com.refrigerator.app.entity.Recipe;
import com.refrigerator.app.entity.RecipeIngredient;
import com.refrigerator.app.entity.User;
import com.refrigerator.app.entity.UserIngredient;
import com.refrigerator.app.entity.UserAllergy;
import com.refrigerator.app.repository.RecipeRepository;
import com.refrigerator.app.repository.UserAllergyRepository;
import com.refrigerator.app.repository.UserIngredientRepository;
import com.refrigerator.app.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class RecipeService {

    @Value("${gemini.api.key}")
    private String geminiApiKey;

    @Value("${gemini.api.url}")
    private String geminiApiUrl;

    @Value("${youtube.api.key}")
    private String youtubeApiKey;

    @Value("${youtube.api.url}")
    private String youtubeApiUrl;

    private final RecipeRepository recipeRepository;
    private final UserRepository userRepository;
    private final UserIngredientRepository ingredientRepository;
    private final UserAllergyRepository allergyRepository;
    private final WebClient.Builder webClientBuilder;

    public RecipeService(RecipeRepository recipeRepository, UserRepository userRepository,
                         UserIngredientRepository ingredientRepository, UserAllergyRepository allergyRepository,
                         WebClient.Builder webClientBuilder) {
        this.recipeRepository = recipeRepository;
        this.userRepository = userRepository;
        this.ingredientRepository = ingredientRepository;
        this.allergyRepository = allergyRepository;
        this.webClientBuilder = webClientBuilder;
    }

    private List<String> getAllergens(Long userId) {
        return allergyRepository.findByUserUserId(userId).stream()
                .map(UserAllergy::getAllergen)
                .collect(Collectors.toList());
    }

    // 프롬프트에 붙일 알레르기 제외 규칙 (알레르기 없으면 빈 문자열)
    private String allergyRule(List<String> allergens) {
        if (allergens.isEmpty()) return "";
        return "- [안전 규칙] 사용자에게 다음 알레르기가 있습니다: " + AllergenMatcher.describeForPrompt(allergens) + "\n" +
               "  이 재료와 이를 원료로 한 양념·가공품은 주재료와 양념 모두에 절대 사용하지 마세요.\n";
    }

    // Gemini가 규칙을 어겨도 알레르기 재료가 든 레시피는 걸러냄
    private List<Map<String, String>> excludeAllergenRecipes(List<Map<String, String>> recipes, List<String> allergens) {
        if (allergens.isEmpty()) return recipes;
        return recipes.stream()
                .filter(r -> {
                    String ingredientLine = r.getOrDefault("description", "").split("\n")[0];
                    return !AllergenMatcher.containsAny(ingredientLine, allergens);
                })
                .collect(Collectors.toList());
    }

    @Transactional
    public List<RecipeResponseDto> recommendRecipes(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

        List<UserIngredient> userIngredients = ingredientRepository.findByUserUserIdAndStatus(userId, "ACTIVE");
        List<String> allergens = getAllergens(userId);
        // 알레르기 재료는 추천에 쓸 재료 후보에서 제외
        List<String> ingredientNames = userIngredients.stream()
                .map(UserIngredient::getIngredientName)
                .filter(name -> AllergenMatcher.match(name, allergens).isEmpty())
                .distinct()
                .collect(Collectors.toList());

        if (ingredientNames.isEmpty()) {
            return new ArrayList<>();
        }

        // Gemini 1번 호출로 3개 레시피(이름+재료+조리법) 전부 생성
        List<Map<String, String>> recipeDataList = excludeAllergenRecipes(
                callGeminiForAllRecipes(ingredientNames, allergens), allergens);

        // 각 레시피 이름으로 YouTube 검색 후 저장
        List<RecipeResponseDto> results = new ArrayList<>();
        for (Map<String, String> recipeData : recipeDataList) {
            try {
                String name = recipeData.get("name");
                String description = recipeData.get("description");

                Map<String, String> yt = searchYoutubeResult(name);

                Recipe recipe = Recipe.builder()
                        .user(user)
                        .title(name)
                        .description(description)
                        .youtubeUrl(yt != null && yt.get("videoId") != null
                                ? "https://www.youtube.com/watch?v=" + yt.get("videoId") : null)
                        .youtubeTitle(yt != null ? yt.getOrDefault("videoTitle", "") : "")
                        .build();

                recipeRepository.save(recipe);
                results.add(toResponseDto(recipe));
            } catch (Exception e) {
                // 한 레시피 실패 시 나머지 계속 진행
            }
        }

        trimOldRecipes(userId);
        return results;
    }

    private void trimOldRecipes(Long userId) {
        int maxCount = 15;
        List<Recipe> unsaved = recipeRepository.findUnsavedOrderByCreatedAtAsc(userId);
        if (unsaved.size() > maxCount) {
            recipeRepository.deleteAll(unsaved.subList(0, unsaved.size() - maxCount));
        }
    }

    @Transactional
    public List<RecipeResponseDto> getUserRecipes(Long userId) {
        trimOldRecipes(userId);
        return recipeRepository.findByUserUserIdOrderByCreatedAtDesc(userId)
                .stream()
                .map(this::toResponseDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public void toggleSave(Long recipeId) {
        Recipe recipe = recipeRepository.findById(recipeId)
                .orElseThrow(() -> new RuntimeException("레시피를 찾을 수 없습니다."));
        recipe.setIsSaved(recipe.getIsSaved() == 1 ? 0 : 1);
        recipeRepository.save(recipe);
    }

    @Transactional
    public void recordView(Long recipeId) {
        Recipe recipe = recipeRepository.findById(recipeId)
                .orElseThrow(() -> new RuntimeException("레시피를 찾을 수 없습니다."));
        recipe.setViewedAt(LocalDateTime.now());
        recipeRepository.save(recipe);
    }

    @Transactional(readOnly = true)
    public List<RecipeResponseDto> getViewHistory(Long userId) {
        return recipeRepository.findRecentlyViewed(userId, PageRequest.of(0, 10))
                .stream()
                .map(this::toResponseDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public void deleteRecipe(Long recipeId) {
        recipeRepository.deleteById(recipeId);
    }

    @Transactional(readOnly = true)
    public List<RecipeResponseDto> searchRecipes(Long userId, String keyword) {
        String likeKeyword = "%" + keyword + "%";
        return recipeRepository.searchByKeyword(userId, likeKeyword)
                .stream()
                .map(this::toResponseDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public List<RecipeResponseDto> recommendRecipesByIngredient(Long userId, String ingredient) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

        // 사용자가 직접 검색한 재료에 해당하는 알레르기는 제외 규칙에서 빼고(화면에서 ⚠ 표시), 나머지는 제외
        List<String> userAllergens = getAllergens(userId);
        List<String> searched = AllergenMatcher.match(ingredient, userAllergens);
        List<String> allergens = userAllergens.stream()
                .filter(a -> !searched.contains(a))
                .collect(Collectors.toList());
        List<Map<String, String>> recipeDataList = excludeAllergenRecipes(
                callGeminiForIngredient(ingredient, allergens), allergens);

        List<RecipeResponseDto> results = new ArrayList<>();
        for (Map<String, String> recipeData : recipeDataList) {
            try {
                String name = recipeData.get("name");
                String description = recipeData.get("description");

                Map<String, String> yt = searchYoutubeResult(name);

                Recipe recipe = Recipe.builder()
                        .user(user)
                        .title(name)
                        .description(description)
                        .youtubeUrl(yt != null && yt.get("videoId") != null
                                ? "https://www.youtube.com/watch?v=" + yt.get("videoId") : null)
                        .youtubeTitle(yt != null ? yt.getOrDefault("videoTitle", "") : "")
                        .build();

                recipeRepository.save(recipe);
                results.add(toResponseDto(recipe));
            } catch (Exception e) {
                // 한 레시피 실패 시 나머지 계속
            }
        }

        return results;
    }

    private List<Map<String, String>> callGeminiForIngredient(String ingredient, List<String> allergens) {
        try {
            String prompt = String.format(
                    "'%s'을(를) 주재료로 한 한국 가정식 요리 3가지를 추천해주세요.\n\n" +
                    "중요 규칙:\n" +
                    "- 실제 한국 가정에서 자주 만드는 현실적인 요리만 추천하세요.\n" +
                    "- 주재료와 맛·조리 방식이 자연스럽게 어울리는 재료 3~5가지만 사용하세요.\n" +
                    "- 부족한 재료는 소금, 간장, 참기름 등 기본 양념류로 보완해도 됩니다.\n" +
                    "%s\n" +
                    "아래 형식으로만 작성하세요. 각 레시피는 정확히 3줄, 레시피 사이에만 빈 줄 하나:\n\n" +
                    "요리이름\n" +
                    "주재료: 재료1 분량, 재료2 분량, 재료3 분량, 재료4 분량, 재료5 분량\n" +
                    "조리법: 1. 단계 2. 단계 3. 단계 4. 단계 5. 단계\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...",
                    ingredient, allergyRule(allergens));

            Map<String, Object> textPart = Map.of("text", prompt);
            Map<String, Object> content = Map.of("parts", List.of(textPart));
            Map<String, Object> requestBody = Map.of("contents", List.of(content));

            WebClient webClient = webClientBuilder.build();
            Map response = webClient.post()
                    .uri(geminiApiUrl + "/gemini-3-flash-preview:generateContent?key=" + geminiApiKey)
                    .header("Content-Type", "application/json")
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(120))
                    .block();

            String text = extractTextFromGeminiResponse(response);
            return parseRecipesFromText(text);
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    // Gemini 1회 호출로 3개 레시피 전체 생성
    private List<Map<String, String>> callGeminiForAllRecipes(List<String> ingredients, List<String> allergens) {
        try {
            String ingredientList = String.join(", ", ingredients);
            String prompt = String.format(
                    "냉장고에 다음 재료들이 있습니다: %s\n\n" +
                    "이 재료 중 실제로 잘 어울리는 것들만 골라 한국 가정식 요리 3가지를 추천해주세요.\n\n" +
                    "중요 규칙:\n" +
                    "- 냉장고 재료 전부를 한 요리에 억지로 넣지 마세요. 맛과 요리 방식이 자연스럽게 어울리는 재료만 사용하세요.\n" +
                    "- 실제 한국 가정에서 자주 만드는 현실적인 요리만 추천하세요 (예: 김치찌개에 방울토마토 X).\n" +
                    "- 각 요리마다 레시피에 적합한 재료 3~5가지만 선택하세요.\n" +
                    "- 부족한 재료는 소금, 간장, 참기름 등 기본 양념류로 보완해도 됩니다.\n" +
                    "%s\n" +
                    "아래 형식으로만 작성하세요. 각 레시피는 정확히 3줄, 레시피 사이에만 빈 줄 하나:\n\n" +
                    "요리이름\n" +
                    "주재료: 재료1 분량, 재료2 분량, 재료3 분량, 재료4 분량, 재료5 분량\n" +
                    "조리법: 1. 단계 2. 단계 3. 단계 4. 단계 5. 단계\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...",
                    ingredientList, allergyRule(allergens));

            Map<String, Object> textPart = Map.of("text", prompt);
            Map<String, Object> content = Map.of("parts", List.of(textPart));
            Map<String, Object> requestBody = Map.of("contents", List.of(content));

            WebClient webClient = webClientBuilder.build();
            Map response = webClient.post()
                    .uri(geminiApiUrl + "/gemini-3-flash-preview:generateContent?key=" + geminiApiKey)
                    .header("Content-Type", "application/json")
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(120))
                    .block();

            String text = extractTextFromGeminiResponse(response);
            return parseRecipesFromText(text);
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    private List<Map<String, String>> parseRecipesFromText(String text) {
        List<Map<String, String>> recipes = new ArrayList<>();
        String[] blocks = text.split("\n\n");
        for (String block : blocks) {
            block = block.trim();
            if (block.isEmpty()) continue;
            String[] lines = block.split("\n");
            if (lines.length < 3) continue;

            String name = lines[0].replaceAll("^\\d+[.)\\s]+", "").trim();
            String ingredients = "";
            String steps = "";
            for (int i = 1; i < lines.length; i++) {
                String line = lines[i].trim();
                if (line.startsWith("주재료:")) ingredients = line;
                else if (line.startsWith("조리법:")) steps = line;
            }
            if (name.isEmpty() || ingredients.isEmpty() || steps.isEmpty()) continue;

            Map<String, String> entry = new HashMap<>();
            entry.put("name", name);
            entry.put("description", ingredients + "\n" + steps);
            recipes.add(entry);
            if (recipes.size() == 3) break;
        }
        return recipes;
    }

    @SuppressWarnings("unchecked")
    private String extractTextFromGeminiResponse(Map response) {
        try {
            List<Map> candidates = (List<Map>) response.get("candidates");
            Map content = (Map) candidates.get(0).get("content");
            List<Map> parts = (List<Map>) content.get("parts");
            return (String) parts.get(0).get("text");
        } catch (Exception e) {
            return "";
        }
    }

    // ──────────── 영상 기반 레시피 (상세 화면 진입 시) ────────────

    // description에 이 줄이 있으면 이미 영상 내용으로 정리된 레시피
    private static final String VIDEO_SOURCE_LINE = "출처: 영상";

    private static final String VIDEO_RECIPE_FORMAT =
            "아래 형식으로만 작성하세요 (정확히 3줄, 다른 말 금지):\n" +
            "요리이름\n" +
            "주재료: 재료1 분량, 재료2 분량, ... (양념 포함, 영상에 나온 재료 전부)\n" +
            "조리법: 1. 단계 2. 단계 3. 단계 ... (영상의 순서대로)\n";

    /**
     * 레시피에 연결된 유튜브 영상의 실제 내용으로 재료·조리법을 다시 정리한다.
     * 1순위: 영상 설명란, 2순위: Gemini 영상 분석. 둘 다 실패하면 기존 레시피를 그대로 반환.
     */
    @Transactional
    public RecipeResponseDto syncRecipeWithVideo(Long recipeId) {
        Recipe recipe = recipeRepository.findById(recipeId)
                .orElseThrow(() -> new RuntimeException("레시피를 찾을 수 없습니다."));

        String desc = recipe.getDescription();
        if (recipe.getYoutubeUrl() == null || (desc != null && desc.contains(VIDEO_SOURCE_LINE))) {
            return toResponseDto(recipe);
        }

        String videoId = extractVideoId(recipe.getYoutubeUrl());
        if (videoId == null) return toResponseDto(recipe);

        Map<String, String> extracted = null;

        // 1순위: 영상 설명란에 적힌 레시피 정리
        String videoDescription = fetchVideoDescription(videoId);
        if (videoDescription != null && videoDescription.length() > 30) {
            extracted = extractRecipeFromVideoDescription(recipe.getYoutubeTitle(), videoDescription);
        }

        // 2순위: Gemini가 영상을 직접 분석
        if (extracted == null) {
            extracted = extractRecipeFromVideo(recipe.getYoutubeUrl());
        }

        if (extracted == null) return toResponseDto(recipe);

        recipe.setTitle(extracted.get("name"));
        recipe.setDescription(extracted.get("description") + "\n" + VIDEO_SOURCE_LINE);
        recipeRepository.save(recipe);
        return toResponseDto(recipe);
    }

    private String extractVideoId(String youtubeUrl) {
        int idx = youtubeUrl.indexOf("v=");
        if (idx < 0) return null;
        String id = youtubeUrl.substring(idx + 2);
        int amp = id.indexOf('&');
        return amp >= 0 ? id.substring(0, amp) : id;
    }

    // search API의 snippet.description은 잘려 있으므로 videos API로 전체 설명란 조회
    @SuppressWarnings("unchecked")
    private String fetchVideoDescription(String videoId) {
        try {
            WebClient webClient = webClientBuilder.baseUrl(youtubeApiUrl).build();
            Map response = webClient.get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/videos")
                            .queryParam("part", "snippet")
                            .queryParam("id", videoId)
                            .queryParam("key", youtubeApiKey)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();

            List<Map> items = (List<Map>) response.get("items");
            if (items == null || items.isEmpty()) return null;
            Map snippet = (Map) items.get(0).get("snippet");
            return (String) snippet.get("description");
        } catch (Exception e) {
            return null;
        }
    }

    private Map<String, String> extractRecipeFromVideoDescription(String videoTitle, String videoDescription) {
        String prompt =
                "다음은 유튜브 요리 영상의 제목과 설명란입니다.\n\n" +
                "제목: " + (videoTitle == null ? "" : videoTitle) + "\n" +
                "설명란:\n" + videoDescription + "\n\n" +
                "설명란에 이 영상 요리의 재료(분량)와 조리 순서가 적혀 있으면, 설명란 내용만 근거로 정리하세요.\n" +
                "- 설명란에 없는 재료나 단계를 지어내지 마세요.\n" +
                "- 재료 목록이나 조리 순서가 설명란에 없으면 다른 말 없이 '없음' 한 단어만 출력하세요.\n\n" +
                VIDEO_RECIPE_FORMAT;
        return parseSingleRecipe(callGemini(List.of(Map.of("text", prompt)), 60));
    }

    private Map<String, String> extractRecipeFromVideo(String youtubeUrl) {
        String prompt =
                "이 유튜브 요리 영상을 보고, 영상에서 실제로 사용한 재료(분량)와 조리 순서를 정리하세요.\n" +
                "- 영상에 나오지 않은 재료나 단계를 지어내지 마세요.\n" +
                "- 분량이 영상에 나오지 않으면 '적당량'으로 쓰세요.\n" +
                "- 요리 영상이 아니면 다른 말 없이 '없음' 한 단어만 출력하세요.\n\n" +
                VIDEO_RECIPE_FORMAT;
        List<Map<String, Object>> parts = List.of(
                Map.of("fileData", Map.of("fileUri", youtubeUrl)),
                Map.of("text", prompt));
        return parseSingleRecipe(callGemini(parts, 120));
    }

    private String callGemini(List<? extends Map<String, ?>> parts, int timeoutSeconds) {
        try {
            Map<String, Object> requestBody = Map.of("contents", List.of(Map.of("parts", parts)));
            Map response = webClientBuilder.build().post()
                    .uri(geminiApiUrl + "/gemini-3-flash-preview:generateContent?key=" + geminiApiKey)
                    .header("Content-Type", "application/json")
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(timeoutSeconds))
                    .block();
            return extractTextFromGeminiResponse(response);
        } catch (Exception e) {
            return "";
        }
    }

    private Map<String, String> parseSingleRecipe(String text) {
        if (text == null || text.isBlank() || text.trim().startsWith("없음")) return null;
        // 3줄 형식이 빈 줄로 나뉘어 와도 처리되도록 빈 줄 제거 후 파싱
        String compact = text.replace("```", "").replaceAll("\\n\\s*\\n", "\n").trim();
        List<Map<String, String>> parsed = parseRecipesFromText(compact);
        return parsed.isEmpty() ? null : parsed.get(0);
    }

    @SuppressWarnings("unchecked")
    private Map<String, String> searchYoutubeResult(String recipeTitle) {
        try {
            WebClient webClient = webClientBuilder.baseUrl(youtubeApiUrl).build();
            Map response = webClient.get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/search")
                            .queryParam("part", "snippet")
                            .queryParam("q", recipeTitle + " 만들기 레시피")
                            .queryParam("type", "video")
                            .queryParam("maxResults", "1")
                            .queryParam("relevanceLanguage", "ko")
                            .queryParam("regionCode", "KR")
                            .queryParam("key", youtubeApiKey)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();

            List<Map> items = (List<Map>) response.get("items");
            if (items == null || items.isEmpty()) return null;

            Map item = items.get(0);
            Map id = (Map) item.get("id");
            Map snippet = (Map) item.get("snippet");

            Map<String, String> result = new HashMap<>();
            result.put("videoId", (String) id.get("videoId"));
            result.put("videoTitle", (String) snippet.get("title"));
            result.put("channelTitle", (String) snippet.get("channelTitle"));
            return result;
        } catch (Exception e) {
            return null;
        }
    }

    private RecipeResponseDto toResponseDto(Recipe recipe) {
        List<RecipeResponseDto.RecipeIngredientDto> ingredientDtos = new ArrayList<>();
        if (recipe.getRecipeIngredients() != null) {
            ingredientDtos = recipe.getRecipeIngredients().stream()
                    .map(ri -> RecipeResponseDto.RecipeIngredientDto.builder()
                            .ingredientName(ri.getIngredientName())
                            .amount(ri.getAmount())
                            .isAvailable(ri.getIsAvailable())
                            .build())
                    .collect(Collectors.toList());
        }

        return RecipeResponseDto.builder()
                .recipeId(recipe.getRecipeId())
                .title(recipe.getTitle())
                .description(recipe.getDescription())
                .cookingTime(recipe.getCookingTime())
                .difficulty(recipe.getDifficulty())
                .servings(recipe.getServings())
                .youtubeUrl(recipe.getYoutubeUrl())
                .youtubeTitle(recipe.getYoutubeTitle())
                .isSaved(recipe.getIsSaved())
                .createdAt(recipe.getCreatedAt())
                .viewedAt(recipe.getViewedAt())
                .ingredients(ingredientDtos)
                .build();
    }
}
