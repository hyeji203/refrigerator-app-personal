package com.refrigerator.app.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "USER_INGREDIENTS")
public class UserIngredient {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "USER_INGREDIENT_ID")
    private Long userIngredientId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "USER_ID", nullable = false)
    private User user;

    @Column(name = "INGREDIENT_NAME", nullable = false, length = 100)
    private String ingredientName;

    @Column(name = "QUANTITY", length = 50)
    private String quantity;

    @Column(name = "EXPIRY_DATE")
    private LocalDate expiryDate;

    @Column(name = "ADDED_METHOD", length = 20)
    private String addedMethod;

    @Column(name = "STATUS", length = 20)
    private String status;

    @Column(name = "CREATED_AT")
    private LocalDateTime createdAt;

    @Column(name = "UPDATED_AT")
    private LocalDateTime updatedAt;

    public UserIngredient() {}

    @PrePersist
    public void prePersist() {
        this.addedMethod = (this.addedMethod == null) ? "MANUAL" : this.addedMethod;
        this.status = "ACTIVE";
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    public void preUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public Long getUserIngredientId() { return userIngredientId; }
    public void setUserIngredientId(Long userIngredientId) { this.userIngredientId = userIngredientId; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
    public String getIngredientName() { return ingredientName; }
    public void setIngredientName(String ingredientName) { this.ingredientName = ingredientName; }
    public String getQuantity() { return quantity; }
    public void setQuantity(String quantity) { this.quantity = quantity; }
    public LocalDate getExpiryDate() { return expiryDate; }
    public void setExpiryDate(LocalDate expiryDate) { this.expiryDate = expiryDate; }
    public String getAddedMethod() { return addedMethod; }
    public void setAddedMethod(String addedMethod) { this.addedMethod = addedMethod; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private User user;
        private String ingredientName;
        private String quantity;
        private LocalDate expiryDate;
        private String addedMethod;

        public Builder user(User user) { this.user = user; return this; }
        public Builder ingredientName(String ingredientName) { this.ingredientName = ingredientName; return this; }
        public Builder quantity(String quantity) { this.quantity = quantity; return this; }
        public Builder expiryDate(LocalDate expiryDate) { this.expiryDate = expiryDate; return this; }
        public Builder addedMethod(String addedMethod) { this.addedMethod = addedMethod; return this; }

        public UserIngredient build() {
            UserIngredient ui = new UserIngredient();
            ui.user = user;
            ui.ingredientName = ingredientName;
            ui.quantity = quantity;
            ui.expiryDate = expiryDate;
            ui.addedMethod = addedMethod;
            return ui;
        }
    }
}
