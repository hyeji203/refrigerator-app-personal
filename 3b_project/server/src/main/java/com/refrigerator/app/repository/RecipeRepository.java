package com.refrigerator.app.repository;

import com.refrigerator.app.entity.Recipe;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface RecipeRepository extends JpaRepository<Recipe, Long> {

    // 사용자의 레시피 목록 (최신순)
    List<Recipe> findByUserUserIdOrderByCreatedAtDesc(Long userId);

    // 사용자의 즐겨찾기 레시피
    List<Recipe> findByUserUserIdAndIsSaved(Long userId, Integer isSaved);

    // 북마크 안 된 레시피 (오래된 순, isSaved=0 또는 NULL)
    @Query("SELECT r FROM Recipe r WHERE r.user.userId = :userId AND (r.isSaved = 0 OR r.isSaved IS NULL) ORDER BY r.createdAt ASC")
    List<Recipe> findUnsavedOrderByCreatedAtAsc(@Param("userId") Long userId);

    // 최근 조회한 레시피 (viewedAt 기준 내림차순)
    @Query("SELECT r FROM Recipe r WHERE r.user.userId = :userId AND r.viewedAt IS NOT NULL ORDER BY r.viewedAt DESC")
    List<Recipe> findRecentlyViewed(@Param("userId") Long userId, Pageable pageable);

    // 요리 이름 또는 재료로 검색
    @Query("SELECT r FROM Recipe r WHERE r.user.userId = :userId AND (r.title LIKE :keyword OR r.description LIKE :keyword)")
    List<Recipe> searchByKeyword(@Param("userId") Long userId, @Param("keyword") String keyword);
}
