package com.refrigerator.app.controller;

import com.refrigerator.app.dto.RecipeResponseDto;
import com.refrigerator.app.service.RecipeService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/recipes")
@CrossOrigin(origins = "*")
public class RecipeController {

    private final RecipeService recipeService;

    public RecipeController(RecipeService recipeService) {
        this.recipeService = recipeService;
    }

    // 보유 재료로 레시피 추천 (Gemini AI 호출)
    @PostMapping("/recommend/{userId}")
    public ResponseEntity<List<RecipeResponseDto>> recommendRecipes(@PathVariable Long userId) {
        return ResponseEntity.ok(recipeService.recommendRecipes(userId));
    }

    // 사용자의 저장된 레시피 목록 조회
    @GetMapping("/user/{userId}")
    public ResponseEntity<List<RecipeResponseDto>> getUserRecipes(@PathVariable Long userId) {
        return ResponseEntity.ok(recipeService.getUserRecipes(userId));
    }

    // 즐겨찾기 토글
    @PatchMapping("/{recipeId}/save")
    public ResponseEntity<Void> toggleSave(@PathVariable Long recipeId) {
        recipeService.toggleSave(recipeId);
        return ResponseEntity.ok().build();
    }

    // 조회 기록 저장
    @PatchMapping("/{recipeId}/view")
    public ResponseEntity<Void> recordView(@PathVariable Long recipeId) {
        recipeService.recordView(recipeId);
        return ResponseEntity.ok().build();
    }

    // 연결된 유튜브 영상 내용으로 재료·조리법 재정리 (상세 화면 진입 시 호출)
    @PostMapping("/{recipeId}/video-recipe")
    public ResponseEntity<RecipeResponseDto> syncWithVideo(@PathVariable Long recipeId) {
        return ResponseEntity.ok(recipeService.syncRecipeWithVideo(recipeId));
    }

    // 최근 본 레시피 (최대 10개)
    @GetMapping("/user/{userId}/history")
    public ResponseEntity<List<RecipeResponseDto>> getViewHistory(@PathVariable Long userId) {
        return ResponseEntity.ok(recipeService.getViewHistory(userId));
    }

    // 요리 이름 또는 재료로 검색
    @GetMapping("/search")
    public ResponseEntity<List<RecipeResponseDto>> searchRecipes(
            @RequestParam Long userId,
            @RequestParam String keyword) {
        return ResponseEntity.ok(recipeService.searchRecipes(userId, keyword));
    }

    // 재료 하나로 AI 레시피 생성
    @PostMapping("/recommend-by-ingredient/{userId}")
    public ResponseEntity<List<RecipeResponseDto>> recommendByIngredient(
            @PathVariable Long userId,
            @RequestParam String ingredient) {
        return ResponseEntity.ok(recipeService.recommendRecipesByIngredient(userId, ingredient));
    }

    // 레시피 삭제
    @DeleteMapping("/{recipeId}")
    public ResponseEntity<Void> deleteRecipe(@PathVariable Long recipeId) {
        recipeService.deleteRecipe(recipeId);
        return ResponseEntity.noContent().build();
    }
}
