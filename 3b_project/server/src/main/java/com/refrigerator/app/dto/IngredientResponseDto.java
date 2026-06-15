package com.refrigerator.app.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class IngredientResponseDto {
    private Long userIngredientId;
    private String ingredientName;
    private String quantity;
    private LocalDate expiryDate;
    private String addedMethod;
    private String status;
    private LocalDateTime createdAt;
    private boolean expiringSoon;
    private boolean expired;

    public IngredientResponseDto() {}

    public IngredientResponseDto(Long userIngredientId, String ingredientName, String quantity,
                                  LocalDate expiryDate, String addedMethod, String status,
                                  LocalDateTime createdAt, boolean expiringSoon, boolean expired) {
        this.userIngredientId = userIngredientId;
        this.ingredientName = ingredientName;
        this.quantity = quantity;
        this.expiryDate = expiryDate;
        this.addedMethod = addedMethod;
        this.status = status;
        this.createdAt = createdAt;
        this.expiringSoon = expiringSoon;
        this.expired = expired;
    }

    public Long getUserIngredientId() { return userIngredientId; }
    public void setUserIngredientId(Long userIngredientId) { this.userIngredientId = userIngredientId; }
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
    public boolean isExpiringSoon() { return expiringSoon; }
    public void setExpiringSoon(boolean expiringSoon) { this.expiringSoon = expiringSoon; }
    public boolean isExpired() { return expired; }
    public void setExpired(boolean expired) { this.expired = expired; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private Long userIngredientId;
        private String ingredientName;
        private String quantity;
        private LocalDate expiryDate;
        private String addedMethod;
        private String status;
        private LocalDateTime createdAt;
        private boolean expiringSoon;
        private boolean expired;

        public Builder userIngredientId(Long userIngredientId) { this.userIngredientId = userIngredientId; return this; }
        public Builder ingredientName(String ingredientName) { this.ingredientName = ingredientName; return this; }
        public Builder quantity(String quantity) { this.quantity = quantity; return this; }
        public Builder expiryDate(LocalDate expiryDate) { this.expiryDate = expiryDate; return this; }
        public Builder addedMethod(String addedMethod) { this.addedMethod = addedMethod; return this; }
        public Builder status(String status) { this.status = status; return this; }
        public Builder createdAt(LocalDateTime createdAt) { this.createdAt = createdAt; return this; }
        public Builder expiringSoon(boolean expiringSoon) { this.expiringSoon = expiringSoon; return this; }
        public Builder expired(boolean expired) { this.expired = expired; return this; }

        public IngredientResponseDto build() {
            return new IngredientResponseDto(userIngredientId, ingredientName, quantity,
                    expiryDate, addedMethod, status, createdAt, expiringSoon, expired);
        }
    }
}
