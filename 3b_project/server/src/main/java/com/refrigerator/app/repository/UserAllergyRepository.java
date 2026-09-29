package com.refrigerator.app.repository;

import com.refrigerator.app.entity.UserAllergy;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserAllergyRepository extends JpaRepository<UserAllergy, Long> {
    List<UserAllergy> findByUserUserId(Long userId);
    void deleteByUserUserId(Long userId);
}