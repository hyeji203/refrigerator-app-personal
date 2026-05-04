package com.refrigerator.app.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "RECIPE_INGREDIENTS")
public class RecipeIngredient {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "RECIPE_ING_ID")
    private Long recipeIngId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "RECIPE_ID", nullable = false)
    private Recipe recipe;

    @Column(name = "INGREDIENT_NAME", nullable = false, length = 100)
    private String ingredientName;

    @Column(name = "AMOUNT", length = 50)
    private String amount;

    @Column(name = "IS_AVAILABLE")
    private Integer isAvailable;

    public RecipeIngredient() {}

    @PrePersist
    public void prePersist() {
        this.isAvailable = 0;
    }

    public Long getRecipeIngId() { return recipeIngId; }
    public void setRecipeIngId(Long recipeIngId) { this.recipeIngId = recipeIngId; }
    public Recipe getRecipe() { return recipe; }
    public void setRecipe(Recipe recipe) { this.recipe = recipe; }
    public String getIngredientName() { return ingredientName; }
    public void setIngredientName(String ingredientName) { this.ingredientName = ingredientName; }
    public String getAmount() { return amount; }
    public void setAmount(String amount) { this.amount = amount; }
    public Integer getIsAvailable() { return isAvailable; }
    public void setIsAvailable(Integer isAvailable) { this.isAvailable = isAvailable; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private Recipe recipe;
        private String ingredientName;
        private String amount;

        public Builder recipe(Recipe recipe) { this.recipe = recipe; return this; }
        public Builder ingredientName(String ingredientName) { this.ingredientName = ingredientName; return this; }
        public Builder amount(String amount) { this.amount = amount; return this; }

        public RecipeIngredient build() {
            RecipeIngredient ri = new RecipeIngredient();
            ri.recipe = recipe;
            ri.ingredientName = ingredientName;
            ri.amount = amount;
            return ri;
        }
    }
}
