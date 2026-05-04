package com.refrigerator.app.dto;

import java.time.LocalDateTime;
import java.util.List;

public class RecipeResponseDto {
    private Long recipeId;
    private String title;
    private String description;
    private Integer cookingTime;
    private String difficulty;
    private Integer servings;
    private String youtubeUrl;
    private String youtubeTitle;
    private Integer isSaved;
    private LocalDateTime createdAt;
    private List<RecipeIngredientDto> ingredients;

    public RecipeResponseDto() {}

    public RecipeResponseDto(Long recipeId, String title, String description, Integer cookingTime,
                              String difficulty, Integer servings, String youtubeUrl, String youtubeTitle,
                              Integer isSaved, LocalDateTime createdAt, List<RecipeIngredientDto> ingredients) {
        this.recipeId = recipeId;
        this.title = title;
        this.description = description;
        this.cookingTime = cookingTime;
        this.difficulty = difficulty;
        this.servings = servings;
        this.youtubeUrl = youtubeUrl;
        this.youtubeTitle = youtubeTitle;
        this.isSaved = isSaved;
        this.createdAt = createdAt;
        this.ingredients = ingredients;
    }

    public Long getRecipeId() { return recipeId; }
    public void setRecipeId(Long recipeId) { this.recipeId = recipeId; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public Integer getCookingTime() { return cookingTime; }
    public void setCookingTime(Integer cookingTime) { this.cookingTime = cookingTime; }
    public String getDifficulty() { return difficulty; }
    public void setDifficulty(String difficulty) { this.difficulty = difficulty; }
    public Integer getServings() { return servings; }
    public void setServings(Integer servings) { this.servings = servings; }
    public String getYoutubeUrl() { return youtubeUrl; }
    public void setYoutubeUrl(String youtubeUrl) { this.youtubeUrl = youtubeUrl; }
    public String getYoutubeTitle() { return youtubeTitle; }
    public void setYoutubeTitle(String youtubeTitle) { this.youtubeTitle = youtubeTitle; }
    public Integer getIsSaved() { return isSaved; }
    public void setIsSaved(Integer isSaved) { this.isSaved = isSaved; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public List<RecipeIngredientDto> getIngredients() { return ingredients; }
    public void setIngredients(List<RecipeIngredientDto> ingredients) { this.ingredients = ingredients; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private Long recipeId;
        private String title;
        private String description;
        private Integer cookingTime;
        private String difficulty;
        private Integer servings;
        private String youtubeUrl;
        private String youtubeTitle;
        private Integer isSaved;
        private LocalDateTime createdAt;
        private List<RecipeIngredientDto> ingredients;

        public Builder recipeId(Long recipeId) { this.recipeId = recipeId; return this; }
        public Builder title(String title) { this.title = title; return this; }
        public Builder description(String description) { this.description = description; return this; }
        public Builder cookingTime(Integer cookingTime) { this.cookingTime = cookingTime; return this; }
        public Builder difficulty(String difficulty) { this.difficulty = difficulty; return this; }
        public Builder servings(Integer servings) { this.servings = servings; return this; }
        public Builder youtubeUrl(String youtubeUrl) { this.youtubeUrl = youtubeUrl; return this; }
        public Builder youtubeTitle(String youtubeTitle) { this.youtubeTitle = youtubeTitle; return this; }
        public Builder isSaved(Integer isSaved) { this.isSaved = isSaved; return this; }
        public Builder createdAt(LocalDateTime createdAt) { this.createdAt = createdAt; return this; }
        public Builder ingredients(List<RecipeIngredientDto> ingredients) { this.ingredients = ingredients; return this; }

        public RecipeResponseDto build() {
            return new RecipeResponseDto(recipeId, title, description, cookingTime, difficulty,
                    servings, youtubeUrl, youtubeTitle, isSaved, createdAt, ingredients);
        }
    }

    public static class RecipeIngredientDto {
        private String ingredientName;
        private String amount;
        private Integer isAvailable;

        public RecipeIngredientDto() {}

        public RecipeIngredientDto(String ingredientName, String amount, Integer isAvailable) {
            this.ingredientName = ingredientName;
            this.amount = amount;
            this.isAvailable = isAvailable;
        }

        public String getIngredientName() { return ingredientName; }
        public void setIngredientName(String ingredientName) { this.ingredientName = ingredientName; }
        public String getAmount() { return amount; }
        public void setAmount(String amount) { this.amount = amount; }
        public Integer getIsAvailable() { return isAvailable; }
        public void setIsAvailable(Integer isAvailable) { this.isAvailable = isAvailable; }

        public static RecipeIngredientDtoBuilder builder() { return new RecipeIngredientDtoBuilder(); }

        public static class RecipeIngredientDtoBuilder {
            private String ingredientName;
            private String amount;
            private Integer isAvailable;

            public RecipeIngredientDtoBuilder ingredientName(String ingredientName) { this.ingredientName = ingredientName; return this; }
            public RecipeIngredientDtoBuilder amount(String amount) { this.amount = amount; return this; }
            public RecipeIngredientDtoBuilder isAvailable(Integer isAvailable) { this.isAvailable = isAvailable; return this; }

            public RecipeIngredientDto build() {
                return new RecipeIngredientDto(ingredientName, amount, isAvailable);
            }
        }
    }
}
