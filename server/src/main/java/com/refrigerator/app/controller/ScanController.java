package com.refrigerator.app.controller;

import com.refrigerator.app.dto.ScanResponseDto;
import com.refrigerator.app.service.ClarifaiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/scan")
public class ScanController {

    private final ClarifaiService clarifaiService;

    public ScanController(ClarifaiService clarifaiService) {
        this.clarifaiService = clarifaiService;
    }

    /**
     * POST /api/scan/analyze
     * Clarifai food-item-recognition API로 사진을 분석하여 식재료 목록만 반환합니다.
     * DB 저장은 하지 않습니다.
     * 사용자가 목록을 검토/편집한 후 /api/ingredients/user/{id}/batch 로 저장합니다.
     */
    @PostMapping("/analyze")
    public ResponseEntity<?> analyze(@RequestParam("image") MultipartFile image) {
        try {
            ScanResponseDto result = clarifaiService.analyzeImage(image);
            return ResponseEntity.ok(result);
        } catch (RuntimeException e) {
            return ResponseEntity.internalServerError()
                    .body(java.util.Map.of("message", e.getMessage()));
        }
    }
}
