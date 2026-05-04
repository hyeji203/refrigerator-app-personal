package com.refrigerator.app.repository;

import com.refrigerator.app.entity.Recipe;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface RecipeRepository extends JpaRepository<Recipe, Long> {

    // 사용자의 레시피 목록 (최신순)
    List<Recipe> findByUserUserIdOrderByCreatedAtDesc(Long userId);

    // 사용자의 즐겨찾기 레시피
    List<Recipe> findByUserUserIdAndIsSaved(Long userId, Integer isSaved);
}
