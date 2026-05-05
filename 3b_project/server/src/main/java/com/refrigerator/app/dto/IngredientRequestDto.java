package com.refrigerator.app.dto;

import java.time.LocalDate;

public class IngredientRequestDto {
    private String ingredientName;
    private String quantity;
    private LocalDate expiryDate;
    private String addedMethod;

    public IngredientRequestDto() {}

    public IngredientRequestDto(String ingredientName, String quantity, LocalDate expiryDate, String addedMethod) {
        this.ingredientName = ingredientName;
        this.quantity = quantity;
        this.expiryDate = expiryDate;
        this.addedMethod = addedMethod;
    }

    public String getIngredientName() { return ingredientName; }
    public void setIngredientName(String ingredientName) { this.ingredientName = ingredientName; }
    public String getQuantity() { return quantity; }
    public void setQuantity(String quantity) { this.quantity = quantity; }
    public LocalDate getExpiryDate() { return expiryDate; }
    public void setExpiryDate(LocalDate expiryDate) { this.expiryDate = expiryDate; }
    public String getAddedMethod() { return addedMethod; }
    public void setAddedMethod(String addedMethod) { this.addedMethod = addedMethod; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private String ingredientName;
        private String quantity;
        private LocalDate expiryDate;
        private String addedMethod;

        public Builder ingredientName(String ingredientName) { this.ingredientName = ingredientName; return this; }
        public Builder quantity(String quantity) { this.quantity = quantity; return this; }
        public Builder expiryDate(LocalDate expiryDate) { this.expiryDate = expiryDate; return this; }
        public Builder addedMethod(String addedMethod) { this.addedMethod = addedMethod; return this; }

        public IngredientRequestDto build() {
            return new IngredientRequestDto(ingredientName, quantity, expiryDate, addedMethod);
        }
    }
}
