import 'package:flutter/material.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/recipe.dart';
import '../utils/auth_utils.dart';
import 'package:mysql1/mysql1.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedIngredients = [];
  List<String> _availableIngredients = [];
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String _sortBy = 'newest';
  RangeValues _cookingTimeRange = const RangeValues(0, 180);
  List<String> _selectedCuisines = [];
  
  final List<String> _cuisineTypes = [
    'All', 'Italian', 'Chinese', 'Indian', 'Mexican', 'Japanese', 'Thai', 'French'
  ];

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _loadRecipes();
  }

  Future<void> _loadIngredients() async {
    try {
      final conn = await DatabaseHelper.getConnection();
      var results = await conn.query('SELECT name FROM ingredients ORDER BY name');
      await conn.close();

      if (!mounted) return;
      setState(() {
        _availableIngredients = results.map((row) => row[0].toString()).toList();
      });
    } catch (e) {
      print('Error loading ingredients: $e');
    }
  }

  Future<void> _loadRecipes() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final conn = await DatabaseHelper.getConnection();
    var results = await conn.query('''
      SELECT 
        r.recipe_id,
        r.title,
        r.description,
        r.cooking_time,
        r.difficulty_level,
        r.cuisine_type,
        r.image_url,
        r.video_url,
        r.created_at,
        GROUP_CONCAT(DISTINCT i.name) as ingredients
      FROM recipes r
      LEFT JOIN recipe_ingredients ri ON r.recipe_id = ri.recipe_id
      LEFT JOIN ingredients i ON ri.ingredient_id = i.ingredient_id
      GROUP BY r.recipe_id
      ORDER BY r.created_at DESC
    ''');
    await conn.close();

    if (!mounted) return;
    setState(() {
      _recipes = results.map((row) {
        // Convert Blob to String if necessary
        Map<String, dynamic> fields = {};
        row.fields.forEach((key, value) {
          if (value is Blob) {
            fields[key] = String.fromCharCodes(value.toBytes());
          } else {
            fields[key] = value;
          }
        });
        return Recipe.fromMap(fields);
      }).toList();
      _isLoading = false;
    });
    
    print('Loaded recipes: ${_recipes.length}'); // Debug print
  } catch (e) {
    print('Error loading recipes: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading recipes: $e'))
      );
    }
  }
}

  Future<void> _filterAndSortRecipes() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final conn = await DatabaseHelper.getConnection();
    
    String query = '''
      SELECT 
        r.recipe_id,
        r.title,
        r.description,
        r.cooking_time,
        r.difficulty_level,
        r.cuisine_type,
        r.image_url,
        r.video_url,
        r.created_at,
        GROUP_CONCAT(DISTINCT i.name) as ingredients
      FROM recipes r
      LEFT JOIN recipe_ingredients ri ON r.recipe_id = ri.recipe_id
      LEFT JOIN ingredients i ON ri.ingredient_id = i.ingredient_id
      WHERE 1=1
    ''';

    List<Object> parameters = [];

    if (_selectedIngredients.isNotEmpty) {
      query += ' AND i.name IN (${List.filled(_selectedIngredients.length, '?').join(',')})';
      parameters.addAll(_selectedIngredients);
    }

    if (_selectedCuisines.isNotEmpty && !_selectedCuisines.contains('All')) {
      query += ' AND r.cuisine_type IN (${List.filled(_selectedCuisines.length, '?').join(',')})';
      parameters.addAll(_selectedCuisines);
    }

    query += ' AND r.cooking_time BETWEEN ? AND ?';
    parameters.add(_cookingTimeRange.start.round());
    parameters.add(_cookingTimeRange.end.round());

    query += ' GROUP BY r.recipe_id';
    
    switch (_sortBy) {
      case 'newest':
        query += ' ORDER BY r.created_at DESC';
        break;
      case 'cooking_time':
        query += ' ORDER BY r.cooking_time ASC';
        break;
      case 'difficulty':
        query += ''' ORDER BY CASE r.difficulty_level 
                      WHEN 'Easy' THEN 1 
                      WHEN 'Medium' THEN 2 
                      WHEN 'Hard' THEN 3 
                      ELSE 4 END''';
        break;
    }

    var results = await conn.query(query, parameters);
    await conn.close();

    if (!mounted) return;
    setState(() {
      _recipes = results.map((row) {
        // Convert Blob to String if necessary
        Map<String, dynamic> fields = {};
        row.fields.forEach((key, value) {
          if (value is Blob) {
            fields[key] = String.fromCharCodes(value.toBytes());
          } else {
            fields[key] = value;
          }
        });
        return Recipe.fromMap(fields);
      }).toList();
      _isLoading = false;
    });
  } catch (e) {
    print('Error filtering recipes: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error filtering recipes: $e'))
      );
    }
  }
}

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Recipes'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cooking Time (minutes)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    RangeSlider(
                      values: _cookingTimeRange,
                      min: 0,
                      max: 180,
                      divisions: 18,
                      labels: RangeLabels(
                        _cookingTimeRange.start.round().toString(),
                        _cookingTimeRange.end.round().toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _cookingTimeRange = values;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cuisine Types',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _cuisineTypes.map((cuisine) {
                        return FilterChip(
                          label: Text(cuisine),
                          selected: _selectedCuisines.contains(cuisine),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedCuisines.add(cuisine);
                              } else {
                                _selectedCuisines.remove(cuisine);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Reset'),
                  onPressed: () {
                    setState(() {
                      _cookingTimeRange = const RangeValues(0, 180);
                      _selectedCuisines.clear();
                    });
                  },
                ),
                FilledButton(
                  child: const Text('Apply'),
                  onPressed: () {
                    Navigator.pop(context);
                    _filterAndSortRecipes();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Finder'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (String value) {
              setState(() {
                _sortBy = value;
              });
              _filterAndSortRecipes();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'newest',
                child: Text('Newest First'),
              ),
              const PopupMenuItem(
                value: 'cooking_time',
                child: Text('Cooking Time'),
              ),
              const PopupMenuItem(
                value: 'difficulty',
                child: Text('Difficulty Level'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.pushNamed(context, '/favorites');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                AuthUtils.logout(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _availableIngredients.where((String ingredient) {
                      return ingredient.toLowerCase()
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String ingredient) {
                    setState(() {
                      if (!_selectedIngredients.contains(ingredient)) {
                        _selectedIngredients.add(ingredient);
                        _filterAndSortRecipes();
                      }
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Search Ingredients',
                        hintText: 'Type to search ingredients',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
                if (_selectedIngredients.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedIngredients.map((ingredient) {
                      return Chip(
                        label: Text(ingredient),
                        onDeleted: () {
                          setState(() {
                            _selectedIngredients.remove(ingredient);
                            _filterAndSortRecipes();
                          });
                        },
                        deleteIcon: const Icon(Icons.close, size: 18),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.no_meals,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recipes found',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try different ingredients or filters',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    :ListView.builder(
  itemCount: _recipes.length,
  padding: const EdgeInsets.all(16),
  itemBuilder: (context, index) {
    final recipe = _recipes[index];
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/recipe-detail', arguments: recipe);
      },
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            if (recipe.imageUrl.isNotEmpty)
              SizedBox(
                height: 200,
                width: double.infinity,
                child: recipe.imageUrl.startsWith('http')
                    ? Image.network(
                        recipe.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.restaurant,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : Image.file(
                        File(recipe.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.restaurant,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
              ),
            
            // Recipe Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.cookingTime} mins',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.restaurant_menu,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.cuisineType,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          recipe.difficultyLevel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (recipe.ingredients.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ingredients: ${recipe.ingredients.join(", ")}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}