package com.refrigerator.app.service;

import com.refrigerator.app.dto.IngredientRequestDto;
import com.refrigerator.app.dto.IngredientResponseDto;
import com.refrigerator.app.entity.User;
import com.refrigerator.app.entity.UserIngredient;
import com.refrigerator.app.repository.UserIngredientRepository;
import com.refrigerator.app.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class IngredientService {

    private final UserIngredientRepository ingredientRepository;
    private final UserRepository userRepository;

    public IngredientService(UserIngredientRepository ingredientRepository, UserRepository userRepository) {
        this.ingredientRepository = ingredientRepository;
        this.userRepository = userRepository;
    }

    // 활성 식재료 목록 조회
    @Transactional(readOnly = true)
    public List<IngredientResponseDto> getActiveIngredients(Long userId) {
        List<UserIngredient> ingredients = ingredientRepository.findByUserUserIdAndStatus(userId, "ACTIVE");
        return ingredients.stream()
                .map(this::toResponseDto)
                .collect(Collectors.toList());
    }

    // 식재료 추가
    @Transactional
    public IngredientResponseDto addIngredient(Long userId, IngredientRequestDto dto) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

        UserIngredient ingredient = UserIngredient.builder()
                .user(user)
                .ingredientName(dto.getIngredientName())
                .quantity(dto.getQuantity())
                .expiryDate(dto.getExpiryDate())
                .addedMethod(dto.getAddedMethod() != null ? dto.getAddedMethod() : "MANUAL")
                .build();

        return toResponseDto(ingredientRepository.save(ingredient));
    }

    // 식재료 수정
    @Transactional
    public IngredientResponseDto updateIngredient(Long ingredientId, IngredientRequestDto dto) {
        UserIngredient ingredient = ingredientRepository.findById(ingredientId)
                .orElseThrow(() -> new RuntimeException("식재료를 찾을 수 없습니다."));

        ingredient.setIngredientName(dto.getIngredientName());
        ingredient.setQuantity(dto.getQuantity());
        ingredient.setExpiryDate(dto.getExpiryDate());

        return toResponseDto(ingredientRepository.save(ingredient));
    }

    // 식재료 삭제
    @Transactional
    public void deleteIngredient(Long ingredientId) {
        ingredientRepository.deleteById(ingredientId);
    }

    // AI 스캔 결과 일괄 저장
    @Transactional
    public List<IngredientResponseDto> addIngredientsBatch(Long userId, List<IngredientRequestDto> dtoList) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

        List<IngredientResponseDto> saved = new java.util.ArrayList<>();
        for (IngredientRequestDto dto : dtoList) {
            if (dto.getIngredientName() == null || dto.getIngredientName().isBlank()) continue;

            UserIngredient ingredient = UserIngredient.builder()
                    .user(user)
                    .ingredientName(dto.getIngredientName().trim())
                    .quantity(dto.getQuantity())
                    .expiryDate(dto.getExpiryDate())
                    .addedMethod(dto.getAddedMethod() != null ? dto.getAddedMethod() : "AI")
                    .build();

            saved.add(toResponseDto(ingredientRepository.save(ingredient)));
        }
        return saved;
    }

    // 유통기한 임박 재료 조회
    @Transactional(readOnly = true)
    public List<IngredientResponseDto> getExpiringIngredients(Long userId, int daysAhead) {
        LocalDate targetDate = LocalDate.now().plusDays(daysAhead);
        List<UserIngredient> ingredients = ingredientRepository.findExpiringIngredients(userId, targetDate);
        return ingredients.stream()
                .map(this::toResponseDto)
                .collect(Collectors.toList());
    }

    private IngredientResponseDto toResponseDto(UserIngredient ingredient) {
        boolean expiringSoon = ingredient.getExpiryDate() != null &&
                !ingredient.getExpiryDate().isAfter(LocalDate.now().plusDays(3));

        return IngredientResponseDto.builder()
                .userIngredientId(ingredient.getUserIngredientId())
                .ingredientName(ingredient.getIngredientName())
                .quantity(ingredient.getQuantity())
                .expiryDate(ingredient.getExpiryDate())
                .addedMethod(ingredient.getAddedMethod())
                .status(ingredient.getStatus())
                .createdAt(ingredient.getCreatedAt())
                .expiringSoon(expiringSoon)
                .build();
    }
}
