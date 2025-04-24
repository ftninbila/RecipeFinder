class Recipe {
  final int id;
  final String title;
  final String description;
  final int cookingTime;
  final String difficultyLevel;
  final String cuisineType;
  final String imageUrl;
  final String videoUrl;
  final DateTime createdAt;
  final List<String> ingredients;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.cookingTime,
    required this.difficultyLevel,
    required this.cuisineType,
    this.imageUrl = '',
    this.videoUrl = '',
    required this.createdAt,
    this.ingredients = const [],
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['recipe_id'] as int,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      cookingTime: (map['cooking_time'] ?? 0) as int,
      difficultyLevel: (map['difficulty_level'] ?? 'Easy') as String,
      cuisineType: (map['cuisine_type'] ?? 'Other') as String,
      imageUrl: map['image_url']?.toString() ?? '',
      videoUrl: map['video_url']?.toString() ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      ingredients: map['ingredients'] != null
          ? (map['ingredients'] as String).split(',')
          : [],
    );
  }
}