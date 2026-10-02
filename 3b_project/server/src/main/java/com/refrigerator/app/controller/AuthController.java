package com.refrigerator.app.controller;

import com.refrigerator.app.dto.AuthResponseDto;
import com.refrigerator.app.dto.LoginRequestDto;
import com.refrigerator.app.dto.RegisterRequestDto;
import com.refrigerator.app.service.AuthService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * POST /api/auth/register
     * 회원가입
     */
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequestDto dto) {
        try {
            AuthResponseDto response = authService.register(dto);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * GET /api/auth/check-id?loginId=xxx
     * 아이디 중복 확인 → { "available": true/false }
     */
    @GetMapping("/check-id")
    public ResponseEntity<?> checkLoginId(@RequestParam String loginId) {
        return ResponseEntity.ok(Map.of("available", authService.isLoginIdAvailable(loginId.trim())));
    }

    /**
     * GET /api/auth/check-email?email=xxx
     * 이메일 중복 확인 → { "available": true/false }
     */
    @GetMapping("/check-email")
    public ResponseEntity<?> checkEmail(@RequestParam String email) {
        return ResponseEntity.ok(Map.of("available", authService.isEmailAvailable(email.trim())));
    }

    /**
     * POST /api/auth/login
     * 로그인
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequestDto dto) {
        try {
            AuthResponseDto response = authService.login(dto);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            return ResponseEntity.status(401).body(Map.of("message", e.getMessage()));
        }
    }
}
