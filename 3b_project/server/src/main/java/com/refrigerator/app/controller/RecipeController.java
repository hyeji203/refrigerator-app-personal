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

    // 레시피 삭제
    @DeleteMapping("/{recipeId}")
    public ResponseEntity<Void> deleteRecipe(@PathVariable Long recipeId) {
        recipeService.deleteRecipe(recipeId);
        return ResponseEntity.noContent().build();
    }
}
