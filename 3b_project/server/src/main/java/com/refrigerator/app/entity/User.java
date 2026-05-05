package com.refrigerator.app.entity;

import jakarta.persistence.*;
import java.util.List;

@Entity
@Table(name = "USERS")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "USER_ID")
    private Long userId;

    @Column(name = "LOGIN_ID", nullable = false, unique = true, length = 50)
    private String loginId;

    @Column(name = "USER_PWD", nullable = false, length = 255)
    private String password;

    @Column(name = "USERNAME", nullable = false, unique = true, length = 50)
    private String username;

    @Column(name = "EMAIL", nullable = false, unique = true, length = 100)
    private String email;

    @Column(name = "PHONE", length = 20)
    private String phone;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL)
    private List<UserIngredient> userIngredients;

    public User() {}

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getLoginId() { return loginId; }
    public void setLoginId(String loginId) { this.loginId = loginId; }
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public List<UserIngredient> getUserIngredients() { return userIngredients; }
    public void setUserIngredients(List<UserIngredient> userIngredients) { this.userIngredients = userIngredients; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private String loginId;
        private String username;
        private String password;
        private String email;
        private String phone;

        public Builder loginId(String loginId) { this.loginId = loginId; return this; }
        public Builder username(String username) { this.username = username; return this; }
        public Builder password(String password) { this.password = password; return this; }
        public Builder email(String email) { this.email = email; return this; }
        public Builder phone(String phone) { this.phone = phone; return this; }

        public User build() {
            User u = new User();
            u.loginId = loginId;
            u.username = username;
            u.password = password;
            u.email = email;
            u.phone = phone;
            return u;
        }
    }
}
