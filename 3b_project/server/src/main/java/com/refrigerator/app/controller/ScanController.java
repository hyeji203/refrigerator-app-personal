package com.refrigerator.app.controller;

import com.refrigerator.app.dto.ScanResponseDto;
import com.refrigerator.app.service.GeminiVisionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/scan")
public class ScanController {

    private final GeminiVisionService geminiVisionService;

    public ScanController(GeminiVisionService geminiVisionService) {
        this.geminiVisionService = geminiVisionService;
    }

    @PostMapping("/analyze")
    public ResponseEntity<?> analyze(@RequestParam("image") MultipartFile image) {
        try {
            ScanResponseDto result = geminiVisionService.analyzeImage(image);
            return ResponseEntity.ok(result);
        } catch (RuntimeException e) {
            return ResponseEntity.internalServerError()
                    .body(java.util.Map.of("message", e.getMessage()));
        }
    }
}
