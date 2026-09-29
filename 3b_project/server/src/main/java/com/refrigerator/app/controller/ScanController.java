package com.refrigerator.app.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.refrigerator.app.dto.ScanResponseDto;
import com.refrigerator.app.entity.ScanHistory;
import com.refrigerator.app.entity.User;
import com.refrigerator.app.repository.ScanHistoryRepository;
import com.refrigerator.app.repository.UserRepository;
import com.refrigerator.app.service.GeminiVisionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/scan")
@CrossOrigin(origins = "*")
public class ScanController {

    private final GeminiVisionService geminiVisionService;
    private final ScanHistoryRepository scanHistoryRepository;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    public ScanController(GeminiVisionService geminiVisionService,
                          ScanHistoryRepository scanHistoryRepository,
                          UserRepository userRepository,
                          ObjectMapper objectMapper) {
        this.geminiVisionService = geminiVisionService;
        this.scanHistoryRepository = scanHistoryRepository;
        this.userRepository = userRepository;
        this.objectMapper = objectMapper;
    }

    /**
     * POST /api/scan/analyze?userId={id}
     * Gemini Vision API로 사진을 분석하고 SCAN_HISTORY에 기록합니다.
     */
    @PostMapping("/analyze")
    public ResponseEntity<?> analyze(
            @RequestParam("image") MultipartFile image,
            @RequestParam(value = "userId", required = false) Long userId) {
        try {
            ScanResponseDto result = geminiVisionService.analyzeImage(image);

            // SCAN_HISTORY 저장 (userId가 있을 때만)
            if (userId != null) {
                userRepository.findById(userId).ifPresent(user -> {
                    try {
                        String json = objectMapper.writeValueAsString(result.getRecognizedIngredients());
                        scanHistoryRepository.save(new ScanHistory(user, json));
                    } catch (Exception ignored) {}
                });
            }

            return ResponseEntity.ok(result);
        } catch (RuntimeException e) {
            return ResponseEntity.internalServerError()
                    .body(java.util.Map.of("message", e.getMessage()));
        }
    }
}
