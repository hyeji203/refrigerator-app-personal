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
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

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
    private final WebClient.Builder webClientBuilder;

    public RecipeService(RecipeRepository recipeRepository, UserRepository userRepository,
                         UserIngredientRepository ingredientRepository, WebClient.Builder webClientBuilder) {
        this.recipeRepository = recipeRepository;
        this.userRepository = userRepository;
        this.ingredientRepository = ingredientRepository;
        this.webClientBuilder = webClientBuilder;
    }

    /**
     * Gemini로 레시피 이름 3개 추출 → 각 이름으로 YouTube 검색 → 영상 기반 레시피 저장
     */
    @Transactional
    public List<RecipeResponseDto> recommendRecipes(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

        List<UserIngredient> userIngredients = ingredientRepository.findByUserUserIdAndStatus(userId, "ACTIVE");
        List<String> ingredientNames = userIngredients.stream()
                .map(UserIngredient::getIngredientName)
                .collect(Collectors.toList());

        if (ingredientNames.isEmpty()) {
            return new ArrayList<>();
        }

        // 1. Gemini: 요리 이름 + 재료 + 조리법을 한 번에 추출
        List<Map<String, String>> recipeInfos = callGeminiForRecipes(ingredientNames);

        // 2. 각 레시피 이름으로 YouTube 검색 → 영상 + Gemini 정보로 레시피 생성
        List<RecipeResponseDto> results = new ArrayList<>();
        for (Map<String, String> info : recipeInfos) {
            String name = info.get("name");
            Map<String, String> yt = searchYoutubeResult(name);
            if (yt == null || yt.get("videoId") == null) continue;

            Recipe recipe = Recipe.builder()
                    .user(user)
                    .title(yt.getOrDefault("videoTitle", name))
                    .description(info.getOrDefault("detail", ""))
                    .youtubeUrl("https://www.youtube.com/watch?v=" + yt.get("videoId"))
                    .youtubeTitle(yt.getOrDefault("channelTitle", ""))
                    .build();

            recipeRepository.save(recipe);
            results.add(toResponseDto(recipe));
        }

        return results;
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

    private List<Map<String, String>> callGeminiForRecipes(List<String> ingredients) {
        String ingredientList = String.join(", ", ingredients);
        String prompt = String.format(
                "냉장고에 다음 재료들이 있습니다: %s\n\n" +
                "이 재료들로 만들 수 있는 한국 요리 3가지를 아래 형식으로만 알려주세요.\n" +
                "각 줄에 하나씩, 파이프(|)로 구분, 번호나 추가 설명 없이:\n" +
                "요리이름|주재료: A, B, C|조리법: 1. 단계 2. 단계 3. 단계\n" +
                "요리이름|주재료: D, E|조리법: 1. 단계 2. 단계\n" +
                "요리이름|주재료: F, G|조리법: 1. 단계 2. 단계",
                ingredientList);

        Map<String, Object> textPart = Map.of("text", prompt);
        Map<String, Object> content = Map.of("parts", List.of(textPart));
        Map<String, Object> requestBody = Map.of("contents", List.of(content));

        WebClient webClient = webClientBuilder.baseUrl(geminiApiUrl).build();
        Map response = webClient.post()
                .uri("/gemini-2.5-flash:generateContent?key=" + geminiApiKey)
                .header("Content-Type", "application/json")
                .bodyValue(requestBody)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        String text = extractTextFromGeminiResponse(response);
        List<Map<String, String>> result = new ArrayList<>();
        for (String line : text.split("\n")) {
            line = line.trim();
            if (line.isEmpty()) continue;
            String[] parts = line.split("\\|");
            if (parts.length < 1) continue;
            String name = parts[0].trim();
            String detail = "";
            if (parts.length >= 3) {
                detail = parts[1].trim() + "\n" + parts[2].trim();
            } else if (parts.length == 2) {
                detail = parts[1].trim();
            }
            Map<String, String> entry = new HashMap<>();
            entry.put("name", name);
            entry.put("detail", detail);
            result.add(entry);
            if (result.size() == 3) break;
        }
        return result;
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

    @SuppressWarnings("unchecked")
    private Map<String, String> searchYoutubeResult(String recipeTitle) {
        try {
            WebClient webClient = webClientBuilder.baseUrl(youtubeApiUrl).build();
            Map response = webClient.get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/search")
                            .queryParam("part", "snippet")
                            .queryParam("q", recipeTitle + " 레시피")
                            .queryParam("type", "video")
                            .queryParam("maxResults", "1")
                            .queryParam("key", youtubeApiKey)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
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
            result.put("videoDescription", (String) snippet.get("description"));
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
