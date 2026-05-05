package com.refrigerator.app.repository;

import com.refrigerator.app.entity.UserIngredient;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;

public interface UserIngredientRepository extends JpaRepository<UserIngredient, Long> {

    // 사용자의 전체 식재료 조회 (활성 상태만)
    List<UserIngredient> findByUserUserIdAndStatus(Long userId, String status);

    // 유통기한 임박 재료 조회 (오늘 + N일 이내)
    @Query("SELECT ui FROM UserIngredient ui WHERE ui.user.userId = :userId " +
           "AND ui.status = 'ACTIVE' AND ui.expiryDate IS NOT NULL " +
           "AND ui.expiryDate <= :targetDate ORDER BY ui.expiryDate ASC")
    List<UserIngredient> findExpiringIngredients(@Param("userId") Long userId,
                                                  @Param("targetDate") LocalDate targetDate);
}
