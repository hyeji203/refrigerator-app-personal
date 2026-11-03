package com.refrigerator.app.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 아이디/비밀번호 찾기용 이메일 인증코드 발송·확인
 * 코드는 DB 대신 메모리에 보관 (서버 재시작 시 사라짐, 5분 유효)
 */
@Service
public class EmailVerificationService {

    public enum Purpose { FIND_ID, RESET_PASSWORD }

    private static final Logger log = LoggerFactory.getLogger(EmailVerificationService.class);
    private static final Duration CODE_TTL = Duration.ofMinutes(5);
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    private static final int MAX_ATTEMPTS = 5;

    private record PendingCode(String code, Instant sentAt, int attempts) {}

    private final Map<String, PendingCode> codes = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();
    // application.properties에 spring.mail.host가 없으면 메일 빈이 없을 수 있음 → null 허용
    private final JavaMailSender mailSender;
    private final String mailFrom;

    public EmailVerificationService(ObjectProvider<JavaMailSender> mailSender,
                                    @Value("${spring.mail.username:}") String mailFrom) {
        this.mailSender = mailSender.getIfAvailable();
        this.mailFrom = mailFrom;
    }

    private static String key(Purpose purpose, String email) {
        return purpose + ":" + email.toLowerCase();
    }

    /**
     * 6자리 인증코드 생성 후 메일 발송
     */
    public void sendCode(Purpose purpose, String email) {
        String key = key(purpose, email);
        PendingCode prev = codes.get(key);
        if (prev != null && prev.sentAt().plus(RESEND_COOLDOWN).isAfter(Instant.now())) {
            long wait = Duration.between(Instant.now(), prev.sentAt().plus(RESEND_COOLDOWN)).getSeconds() + 1;
            throw new RuntimeException(wait + "초 후에 다시 요청해 주세요.");
        }

        String code = String.format("%06d", random.nextInt(1_000_000));
        String title = purpose == Purpose.FIND_ID ? "아이디 찾기" : "비밀번호 재설정";

        if (mailSender == null || mailFrom.isBlank()) {
            // 메일 계정 미설정 시 개발용으로 콘솔에 출력
            log.warn("[인증코드] 메일 미설정 - 메일 대신 콘솔 출력: {} {} → {}", title, email, code);
        } else {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(mailFrom);
            message.setTo(email);
            message.setSubject("[냉장고 요리사] " + title + " 인증코드");
            message.setText("인증코드: " + code + "\n\n"
                    + "앱 화면에 위 6자리 코드를 입력해 주세요. 코드는 5분 동안 유효합니다.\n"
                    + "본인이 요청하지 않았다면 이 메일을 무시해 주세요.");
            try {
                mailSender.send(message);
            } catch (MailException e) {
                log.error("인증코드 메일 발송 실패: {}", e.getMessage());
                throw new IllegalStateException("메일을 보내지 못했어요. 잠시 후 다시 시도해 주세요.");
            }
        }
        codes.put(key, new PendingCode(code, Instant.now(), 0));
    }

    /**
     * 코드가 맞는지 확인. consume=true면 확인 후 코드를 폐기 (재사용 방지)
     */
    public void verify(Purpose purpose, String email, String code, boolean consume) {
        String key = key(purpose, email);
        PendingCode pending = codes.get(key);
        if (pending == null || pending.sentAt().plus(CODE_TTL).isBefore(Instant.now())) {
            codes.remove(key);
            throw new RuntimeException("인증코드가 만료됐어요. 코드를 다시 받아 주세요.");
        }
        if (!pending.code().equals(code == null ? "" : code.trim())) {
            int attempts = pending.attempts() + 1;
            if (attempts >= MAX_ATTEMPTS) {
                codes.remove(key);
                throw new RuntimeException("인증코드를 " + MAX_ATTEMPTS + "번 틀렸어요. 코드를 다시 받아 주세요.");
            }
            codes.put(key, new PendingCode(pending.code(), pending.sentAt(), attempts));
            throw new RuntimeException("인증코드가 일치하지 않아요. (" + attempts + "/" + MAX_ATTEMPTS + ")");
        }
        if (consume) codes.remove(key);
    }
}
