package com.refrigerator.app.dto;

public class AuthResponseDto {
    private Long userId;
    private String loginId;
    private String username;
    private String email;
    private String token;

    public AuthResponseDto() {}

    public AuthResponseDto(Long userId, String loginId, String username, String email, String token) {
        this.userId = userId;
        this.loginId = loginId;
        this.username = username;
        this.email = email;
        this.token = token;
    }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getLoginId() { return loginId; }
    public void setLoginId(String loginId) { this.loginId = loginId; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private Long userId;
        private String loginId;
        private String username;
        private String email;
        private String token;

        public Builder userId(Long userId) { this.userId = userId; return this; }
        public Builder loginId(String loginId) { this.loginId = loginId; return this; }
        public Builder username(String username) { this.username = username; return this; }
        public Builder email(String email) { this.email = email; return this; }
        public Builder token(String token) { this.token = token; return this; }

        public AuthResponseDto build() {
            return new AuthResponseDto(userId, loginId, username, email, token);
        }
    }
}
