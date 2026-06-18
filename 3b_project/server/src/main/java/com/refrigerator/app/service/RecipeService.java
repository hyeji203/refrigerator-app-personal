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
    private final WebClient.Builder webClientBuilder;

    public RecipeService(RecipeRepository recipeRepository, UserRepository userRepository,
                         UserIngredientRepository ingredientRepository, WebClient.Builder webClientBuilder) {
        this.recipeRepository = recipeRepository;
        this.userRepository = userRepository;
        this.ingredientRepository = ingredientRepository;
        this.webClientBuilder = webClientBuilder;
    }

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

        // Gemini 1번 호출로 3개 레시피(이름+재료+조리법) 전부 생성
        List<Map<String, String>> recipeDataList = callGeminiForAllRecipes(ingredientNames);

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
                        .youtubeTitle(yt != null ? yt.getOrDefault("channelTitle", "") : "")
                        .build();

                recipeRepository.save(recipe);
                results.add(toResponseDto(recipe));
            } catch (Exception e) {
                // 한 레시피 실패 시 나머지 계속 진행
            }
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

        List<Map<String, String>> recipeDataList = callGeminiForIngredient(ingredient);

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
                        .youtubeTitle(yt != null ? yt.getOrDefault("channelTitle", "") : "")
                        .build();

                recipeRepository.save(recipe);
                results.add(toResponseDto(recipe));
            } catch (Exception e) {
                // 한 레시피 실패 시 나머지 계속
            }
        }

        return results;
    }

    private List<Map<String, String>> callGeminiForIngredient(String ingredient) {
        try {
            String prompt = String.format(
                    "'%s'을(를) 주재료로 만들 수 있는 한국 요리 3가지의 상세 레시피를 아래 형식으로만 작성하세요.\n" +
                    "각 레시피는 정확히 3줄(이름, 주재료, 조리법), 레시피 사이에만 빈 줄 하나:\n\n" +
                    "요리이름\n" +
                    "주재료: 재료1 분량, 재료2 분량, 재료3 분량, 재료4 분량, 재료5 분량\n" +
                    "조리법: 1. 단계 2. 단계 3. 단계 4. 단계 5. 단계\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...",
                    ingredient);

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
                    .timeout(Duration.ofSeconds(60))
                    .block();

            String text = extractTextFromGeminiResponse(response);
            return parseRecipesFromText(text);
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    // Gemini 1회 호출로 3개 레시피 전체 생성
    private List<Map<String, String>> callGeminiForAllRecipes(List<String> ingredients) {
        try {
            String ingredientList = String.join(", ", ingredients);
            String prompt = String.format(
                    "냉장고에 다음 재료들이 있습니다: %s\n\n" +
                    "이 재료들로 만들 수 있는 한국 요리 3가지의 상세 레시피를 아래 형식으로만 작성하세요.\n" +
                    "각 레시피는 정확히 3줄(이름, 주재료, 조리법), 레시피 사이에만 빈 줄 하나:\n\n" +
                    "요리이름\n" +
                    "주재료: 재료1 분량, 재료2 분량, 재료3 분량, 재료4 분량, 재료5 분량\n" +
                    "조리법: 1. 단계 2. 단계 3. 단계 4. 단계 5. 단계\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...\n\n" +
                    "요리이름\n" +
                    "주재료: ...\n" +
                    "조리법: ...",
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
                    .timeout(Duration.ofSeconds(60))
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
