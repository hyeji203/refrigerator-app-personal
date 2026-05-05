package com.refrigerator.app.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "RECIPES")
public class Recipe {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "RECIPE_ID")
    private Long recipeId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "USER_ID", nullable = false)
    private User user;

    @Column(name = "TITLE", nullable = false, length = 200)
    private String title;

    @Lob
    @Column(name = "DESCRIPTION")
    private String description;

    @Column(name = "COOKING_TIME")
    private Integer cookingTime;

    @Column(name = "DIFFICULTY", length = 20)
    private String difficulty;

    @Column(name = "SERVINGS")
    private Integer servings;

    @Column(name = "YOUTUBE_URL", length = 500)
    private String youtubeUrl;

    @Column(name = "YOUTUBE_TITLE", length = 300)
    private String youtubeTitle;

    @Column(name = "IS_SAVED")
    private Integer isSaved;

    @Column(name = "CREATED_AT")
    private LocalDateTime createdAt;

    @OneToMany(mappedBy = "recipe", cascade = CascadeType.ALL)
    private List<RecipeIngredient> recipeIngredients;

    public Recipe() {}

    @PrePersist
    public void prePersist() {
        this.isSaved = 0;
        this.createdAt = LocalDateTime.now();
    }

    public Long getRecipeId() { return recipeId; }
    public void setRecipeId(Long recipeId) { this.recipeId = recipeId; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
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
    public List<RecipeIngredient> getRecipeIngredients() { return recipeIngredients; }
    public void setRecipeIngredients(List<RecipeIngredient> recipeIngredients) { this.recipeIngredients = recipeIngredients; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private User user;
        private String title;
        private String description;
        private Integer cookingTime;
        private String difficulty;
        private Integer servings;
        private String youtubeUrl;
        private String youtubeTitle;

        public Builder user(User user) { this.user = user; return this; }
        public Builder title(String title) { this.title = title; return this; }
        public Builder description(String description) { this.description = description; return this; }
        public Builder cookingTime(Integer cookingTime) { this.cookingTime = cookingTime; return this; }
        public Builder difficulty(String difficulty) { this.difficulty = difficulty; return this; }
        public Builder servings(Integer servings) { this.servings = servings; return this; }
        public Builder youtubeUrl(String youtubeUrl) { this.youtubeUrl = youtubeUrl; return this; }
        public Builder youtubeTitle(String youtubeTitle) { this.youtubeTitle = youtubeTitle; return this; }

        public Recipe build() {
            Recipe r = new Recipe();
            r.user = user;
            r.title = title;
            r.description = description;
            r.cookingTime = cookingTime;
            r.difficulty = difficulty;
            r.servings = servings;
            r.youtubeUrl = youtubeUrl;
            r.youtubeTitle = youtubeTitle;
            return r;
        }
    }
}
