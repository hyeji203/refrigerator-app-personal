package com.refrigerator.app.controller;

import com.refrigerator.app.entity.User;
import com.refrigerator.app.entity.UserAllergy;
import com.refrigerator.app.repository.UserAllergyRepository;
import com.refrigerator.app.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class AllergyController {

    private final UserAllergyRepository allergyRepository;
    private final UserRepository userRepository;

    public AllergyController(UserAllergyRepository allergyRepository, UserRepository userRepository) {
        this.allergyRepository = allergyRepository;
        this.userRepository = userRepository;
    }

    // GET /api/users/{userId}/allergies
    @GetMapping("/{userId}/allergies")
    public ResponseEntity<?> getAllergies(@PathVariable Long userId) {
        List<UserAllergy> list = allergyRepository.findByUserUserId(userId);
        String joined = list.stream()
                .map(UserAllergy::getAllergen)
                .collect(Collectors.joining(", "));
        return ResponseEntity.ok(Map.of("allergies", joined));
    }

    // POST /api/users/{userId}/allergies
    @Transactional
    @PostMapping("/{userId}/allergies")
    public ResponseEntity<?> saveAllergies(@PathVariable Long userId,
                                           @RequestBody Map<String, String> body) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다"));

        allergyRepository.deleteByUserUserId(userId);

        String raw = body.getOrDefault("allergies", "").trim();
        if (!raw.isEmpty()) {
            List<UserAllergy> newList = Arrays.stream(raw.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .map(s -> new UserAllergy(user, s))
                    .collect(Collectors.toList());
            allergyRepository.saveAll(newList);
        }

        return ResponseEntity.ok(Map.of("message", "알레르기 정보가 저장되었습니다", "allergies", raw));
    }
}
