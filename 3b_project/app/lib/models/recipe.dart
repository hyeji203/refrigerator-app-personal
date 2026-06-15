class Recipe {
  final int recipeId;
  final String title;
  final String? description;
  final int? cookingTime;
  final String? difficulty;
  final int? servings;
  final String? youtubeUrl;
  final String? youtubeTitle;
  final int isSaved;
  final String? createdAt;
  final String? viewedAt;
  final List<RecipeIngredient> ingredients;

  Recipe({
    required this.recipeId,
    required this.title,
    this.description,
    this.cookingTime,
    this.difficulty,
    this.servings,
    this.youtubeUrl,
    this.youtubeTitle,
    required this.isSaved,
    this.createdAt,
    this.viewedAt,
    required this.ingredients,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      recipeId: json['recipeId'],
      title: json['title'],
      description: json['description'],
      cookingTime: json['cookingTime'],
      difficulty: json['difficulty'],
      servings: json['servings'],
      youtubeUrl: json['youtubeUrl'],
      youtubeTitle: json['youtubeTitle'],
      isSaved: json['isSaved'] ?? 0,
      createdAt: json['createdAt'],
      viewedAt: json['viewedAt'],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class RecipeIngredient {
  final String ingredientName;
  final String? amount;
  final int isAvailable;

  RecipeIngredient({
    required this.ingredientName,
    this.amount,
    required this.isAvailable,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      ingredientName: json['ingredientName'],
      amount: json['amount'],
      isAvailable: json['isAvailable'] ?? 0,
    );
  }
}
