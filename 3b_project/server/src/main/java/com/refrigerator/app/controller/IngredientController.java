package com.refrigerator.app.controller;

import com.refrigerator.app.dto.IngredientRequestDto;
import com.refrigerator.app.dto.IngredientResponseDto;
import com.refrigerator.app.service.IngredientService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ingredients")
@CrossOrigin(origins = "*")
public class IngredientController {

    private final IngredientService ingredientService;

    public IngredientController(IngredientService ingredientService) {
        this.ingredientService = ingredientService;
    }

    // 냉장고 식재료 전체 조회
    @GetMapping("/user/{userId}")
    public ResponseEntity<List<IngredientResponseDto>> getIngredients(@PathVariable Long userId) {
        return ResponseEntity.ok(ingredientService.getActiveIngredients(userId));
    }

    // 식재료 추가 (수동)
    @PostMapping("/user/{userId}")
    public ResponseEntity<IngredientResponseDto> addIngredient(
            @PathVariable Long userId,
            @RequestBody IngredientRequestDto requestDto) {
        return ResponseEntity.ok(ingredientService.addIngredient(userId, requestDto));
    }

    // 식재료 수정
    @PutMapping("/{ingredientId}")
    public ResponseEntity<IngredientResponseDto> updateIngredient(
            @PathVariable Long ingredientId,
            @RequestBody IngredientRequestDto requestDto) {
        return ResponseEntity.ok(ingredientService.updateIngredient(ingredientId, requestDto));
    }

    // 식재료 삭제
    @DeleteMapping("/{ingredientId}")
    public ResponseEntity<Void> deleteIngredient(@PathVariable Long ingredientId) {
        ingredientService.deleteIngredient(ingredientId);
        return ResponseEntity.noContent().build();
    }

    // AI 스캔 후 사용자가 확정한 재료 목록 일괄 저장
    @PostMapping("/user/{userId}/batch")
    public ResponseEntity<List<IngredientResponseDto>> addIngredientsBatch(
            @PathVariable Long userId,
            @RequestBody List<IngredientRequestDto> requestList) {
        return ResponseEntity.ok(ingredientService.addIngredientsBatch(userId, requestList));
    }

    // 유통기한 임박 재료 조회 (3일 이내)
    @GetMapping("/user/{userId}/expiring")
    public ResponseEntity<List<IngredientResponseDto>> getExpiringIngredients(@PathVariable Long userId) {
        return ResponseEntity.ok(ingredientService.getExpiringIngredients(userId, 3));
    }
}
