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

    // ──────────────────── 아이디/비밀번호 찾기 ────────────────────

    private static String field(Map<String, String> body, String name) {
        String v = body.get(name);
        return v == null ? "" : v.trim();
    }

    /**
     * POST /api/auth/find-id/send-code  { email }
     */
    @PostMapping("/find-id/send-code")
    public ResponseEntity<?> sendFindIdCode(@RequestBody Map<String, String> body) {
        try {
            authService.sendFindIdCode(field(body, "email"));
            return ResponseEntity.ok(Map.of("message", "인증코드를 보냈어요."));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * POST /api/auth/find-id  { email, code } → { loginId }
     */
    @PostMapping("/find-id")
    public ResponseEntity<?> findLoginId(@RequestBody Map<String, String> body) {
        try {
            String loginId = authService.findLoginId(field(body, "email"), field(body, "code"));
            return ResponseEntity.ok(Map.of("loginId", loginId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * POST /api/auth/reset-password/send-code  { loginId, email }
     */
    @PostMapping("/reset-password/send-code")
    public ResponseEntity<?> sendResetCode(@RequestBody Map<String, String> body) {
        try {
            authService.sendResetCode(field(body, "loginId"), field(body, "email"));
            return ResponseEntity.ok(Map.of("message", "인증코드를 보냈어요."));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * POST /api/auth/reset-password/verify  { loginId, email, code }
     */
    @PostMapping("/reset-password/verify")
    public ResponseEntity<?> verifyResetCode(@RequestBody Map<String, String> body) {
        try {
            authService.verifyResetCode(field(body, "loginId"), field(body, "email"), field(body, "code"));
            return ResponseEntity.ok(Map.of("message", "인증됐어요."));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * POST /api/auth/reset-password  { loginId, email, code, newPassword }
     */
    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody Map<String, String> body) {
        try {
            authService.resetPassword(field(body, "loginId"), field(body, "email"),
                    field(body, "code"), body.get("newPassword"));
            return ResponseEntity.ok(Map.of("message", "비밀번호를 변경했어요."));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}
