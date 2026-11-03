package com.refrigerator.app.service;

import com.refrigerator.app.dto.AuthResponseDto;
import com.refrigerator.app.dto.LoginRequestDto;
import com.refrigerator.app.dto.RegisterRequestDto;
import com.refrigerator.app.entity.User;
import com.refrigerator.app.repository.UserRepository;
import com.refrigerator.app.security.JwtUtil;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final EmailVerificationService emailVerificationService;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtUtil jwtUtil,
                       EmailVerificationService emailVerificationService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.emailVerificationService = emailVerificationService;
    }

    /**
     * 아이디 사용 가능 여부 (회원가입 실시간 중복 확인용)
     */
    @Transactional(readOnly = true)
    public boolean isLoginIdAvailable(String loginId) {
        return !userRepository.existsByLoginId(loginId);
    }

    /**
     * 이메일 사용 가능 여부 (회원가입 실시간 중복 확인용)
     */
    @Transactional(readOnly = true)
    public boolean isEmailAvailable(String email) {
        return !userRepository.existsByEmail(email);
    }

    /**
     * 회원가입
     */
    @Transactional
    public AuthResponseDto register(RegisterRequestDto dto) {
        if (userRepository.existsByLoginId(dto.getLoginId())) {
            throw new RuntimeException("이미 사용 중인 아이디입니다.");
        }
        if (userRepository.existsByUsername(dto.getUsername())) {
            throw new RuntimeException("이미 사용 중인 닉네임입니다.");
        }
        if (userRepository.existsByEmail(dto.getEmail())) {
            throw new RuntimeException("이미 사용 중인 이메일입니다.");
        }

        User user = User.builder()
                .loginId(dto.getLoginId())
                .username(dto.getUsername())
                .password(passwordEncoder.encode(dto.getPassword()))
                .email(dto.getEmail())
                .phone(dto.getPhone())
                .build();

        user = userRepository.save(user);
        String token = jwtUtil.generateToken(user.getUserId(), user.getEmail());

        return AuthResponseDto.builder()
                .userId(user.getUserId())
                .loginId(user.getLoginId())
                .username(user.getUsername())
                .email(user.getEmail())
                .token(token)
                .build();
    }

    /**
     * 로그인
     */
    @Transactional(readOnly = true)
    public AuthResponseDto login(LoginRequestDto dto) {
        User user = userRepository.findByLoginId(dto.getLoginId())
                .orElseThrow(() -> new RuntimeException("아이디 또는 비밀번호가 올바르지 않습니다."));

        if (!passwordEncoder.matches(dto.getPassword(), user.getPassword())) {
            throw new RuntimeException("아이디 또는 비밀번호가 올바르지 않습니다.");
        }

        String token = jwtUtil.generateToken(user.getUserId(), user.getEmail());

        return AuthResponseDto.builder()
                .userId(user.getUserId())
                .loginId(user.getLoginId())
                .username(user.getUsername())
                .email(user.getEmail())
                .token(token)
                .build();
    }

    // ──────────────────── 아이디/비밀번호 찾기 ────────────────────

    /**
     * 아이디 찾기 1단계: 가입 이메일로 인증코드 발송
     */
    @Transactional(readOnly = true)
    public void sendFindIdCode(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("가입되지 않은 이메일이에요."));
        emailVerificationService.sendCode(EmailVerificationService.Purpose.FIND_ID, user.getEmail());
    }

    /**
     * 아이디 찾기 2단계: 코드 확인 후 아이디 반환
     */
    @Transactional(readOnly = true)
    public String findLoginId(String email, String code) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("가입되지 않은 이메일이에요."));
        emailVerificationService.verify(EmailVerificationService.Purpose.FIND_ID, user.getEmail(), code, true);
        return user.getLoginId();
    }

    /**
     * 비밀번호 재설정 1단계: 아이디와 이메일이 같은 계정이면 인증코드 발송
     */
    @Transactional(readOnly = true)
    public void sendResetCode(String loginId, String email) {
        User user = findByLoginIdAndEmail(loginId, email);
        emailVerificationService.sendCode(EmailVerificationService.Purpose.RESET_PASSWORD, user.getEmail());
    }

    /**
     * 비밀번호 재설정 2단계: 코드만 확인 (새 비밀번호 입력 화면으로 넘어가기 전)
     */
    @Transactional(readOnly = true)
    public void verifyResetCode(String loginId, String email, String code) {
        User user = findByLoginIdAndEmail(loginId, email);
        emailVerificationService.verify(EmailVerificationService.Purpose.RESET_PASSWORD, user.getEmail(), code, false);
    }

    /**
     * 비밀번호 재설정 3단계: 코드를 다시 확인하고 새 비밀번호 저장
     */
    @Transactional
    public void resetPassword(String loginId, String email, String code, String newPassword) {
        if (newPassword == null || newPassword.trim().length() < 6) {
            throw new RuntimeException("비밀번호는 6자 이상이어야 해요.");
        }
        User user = findByLoginIdAndEmail(loginId, email);
        emailVerificationService.verify(EmailVerificationService.Purpose.RESET_PASSWORD, user.getEmail(), code, true);
        user.setPassword(passwordEncoder.encode(newPassword.trim()));
        userRepository.save(user);
    }

    private User findByLoginIdAndEmail(String loginId, String email) {
        return userRepository.findByLoginId(loginId)
                .filter(u -> u.getEmail() != null && u.getEmail().equalsIgnoreCase(email))
                .orElseThrow(() -> new RuntimeException("아이디와 이메일이 일치하는 계정이 없어요."));
    }
}
