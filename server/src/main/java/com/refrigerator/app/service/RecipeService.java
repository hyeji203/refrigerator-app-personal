package com.refrigerator.app.service;

import com.refrigerator.app.dto.RecipeResponseDto;
import com.refrigerator.app.entity.Recipe;
import com.refrigerator.app.entity.RecipeIngredient;
import com.refrigerator.app.entity.User;
import com.refrigerator.app.entity.UserIngredient;
import com.refrigerator.app.repository.RecipeRepository;
import com.refrigerator.app.repository.UserIngredientRepository;
import com.refrigerator.app.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

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
    private final WebClient.Builder webClientBuilder;

    public RecipeService(RecipeRepository recipeRepository, UserRepository userRepository,
                         UserIngredientRepository ingredientRepository, WebClient.Builder webClientBuilder) {
        this.recipeRepository = recipeRepository;
        this.userRepository = userRepository;
        this.ingredientRepository = ingredientRepository;
        this.webClientBuilder = webClientBuilder;
    }

    /**
     * 사용자의 보유 재료를 기반으로 Gemini AI가 레시피를 추천합니다.
     */
    @Transactional
    public List<RecipeResponseDto> recommendRecipes(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

        // 1. 보유 식재료 목록 가져오기
        List<UserIngredient> userIngredients = ingredientRepository.findByUserUserIdAndStatus(userId, "ACTIVE");
        List<String> ingredientNames = userIngredients.stream()
                .map(UserIngredient::getIngredientName)
                .collect(Collectors.toList());

        if (ingredientNames.isEmpty()) {
            return new ArrayList<>();
        }

        // 2. Gemini API로 레시피 추천 요청
        String geminiResponse = callGeminiForRecipe(ingredientNames);

        // 3. 응답 파싱 후 레시피 저장 (간단 버전 - 실제 구현 시 JSON 파싱 필요)
        Recipe recipe = parseAndSaveRecipe(user, geminiResponse, ingredientNames);

        // 4. YouTube 영상 검색
        String youtubeUrl = searchYoutubeVideo(recipe.getTitle());
        recipe.setYoutubeUrl(youtubeUrl);
        recipeRepository.save(recipe);

        return List.of(toResponseDto(recipe));
    }

    @Transactional(readOnly = true)
    public List<RecipeResponseDto> getUserRecipes(Long userId) {
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
    public void deleteRecipe(Long recipeId) {
        recipeRepository.deleteById(recipeId);
    }

    private String callGeminiForRecipe(List<String> ingredients) {
        String ingredientList = String.join(", ", ingredients);
        String prompt = String.format(
                "냉장고에 다음 재료들이 있습니다: %s\n\n" +
                "이 재료들로 만들 수 있는 레시피 1개를 추천해주세요.\n" +
                "다음 형식으로 답변해주세요:\n" +
                "제목: [레시피 이름]\n" +
                "조리시간: [분]\n" +
                "난이도: [쉬움/보통/어려움]\n" +
                "인분: [인분 수]\n" +
                "재료: [재료1(양), 재료2(양), ...]\n" +
                "조리법: [단계별 조리법]",
                ingredientList);

        Map<String, Object> textPart = Map.of("text", prompt);
        Map<String, Object> content = Map.of("parts", List.of(textPart));
        Map<String, Object> requestBody = Map.of("contents", List.of(content));

        WebClient webClient = webClientBuilder.baseUrl(geminiApiUrl).build();
        Map response = webClient.post()
                .uri("/gemini-1.5-flash:generateContent?key=" + geminiApiKey)
                .header("Content-Type", "application/json")
                .bodyValue(requestBody)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        return extractTextFromGeminiResponse(response);
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

    private Recipe parseAndSaveRecipe(User user, String geminiText, List<String> userIngredients) {
        // 간단 파싱 (실제 운영 시 정규식 또는 JSON 응답 형식으로 개선 권장)
        String title = extractLine(geminiText, "제목:");
        String cookingTimeStr = extractLine(geminiText, "조리시간:");
        String difficulty = extractLine(geminiText, "난이도:");
        String servingsStr = extractLine(geminiText, "인분:");

        Recipe recipe = Recipe.builder()
                .user(user)
                .title(title.isEmpty() ? "AI 추천 레시피" : title)
                .description(geminiText)
                .cookingTime(parseIntSafe(cookingTimeStr))
                .difficulty(difficulty.isEmpty() ? "보통" : difficulty)
                .servings(parseIntSafe(servingsStr))
                .build();

        return recipeRepository.save(recipe);
    }

    private String searchYoutubeVideo(String recipeTitle) {
        try {
            WebClient webClient = webClientBuilder.baseUrl(youtubeApiUrl).build();
            Map response = webClient.get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/search")
                            .queryParam("part", "snippet")
                            .queryParam("q", recipeTitle + " 레시피 만들기")
                            .queryParam("type", "video")
                            .queryParam("maxResults", "1")
                            .queryParam("key", youtubeApiKey)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            return extractYoutubeUrl(response);
        } catch (Exception e) {
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private String extractYoutubeUrl(Map response) {
        try {
            List<Map> items = (List<Map>) response.get("items");
            Map id = (Map) items.get(0).get("id");
            String videoId = (String) id.get("videoId");
            return "https://www.youtube.com/watch?v=" + videoId;
        } catch (Exception e) {
            return null;
        }
    }

    private String extractLine(String text, String prefix) {
        for (String line : text.split("\n")) {
            if (line.startsWith(prefix)) {
                return line.replace(prefix, "").trim();
            }
        }
        return "";
    }

    private Integer parseIntSafe(String value) {
        try {
            return Integer.parseInt(value.replaceAll("[^0-9]", ""));
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
                .ingredients(ingredientDtos)
                .build();
    }
}
