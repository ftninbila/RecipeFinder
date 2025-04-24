// lib/screens/manage_recipes_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../utils/session_manager.dart';
import '../widgets/admin_drawer.dart';

class ManageRecipesScreen extends StatefulWidget {
  const ManageRecipesScreen({Key? key}) : super(key: key);

  @override
  State<ManageRecipesScreen> createState() => _ManageRecipesScreenState();
}

class _ManageRecipesScreenState extends State<ManageRecipesScreen> {
  String adminEmail = '';
  List<Map<String, dynamic>> recipes = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _loadRecipes();
  }

  Future<void> _loadAdminData() async {
    try {
      final email = await SessionManager.getEmail();
      setState(() {
        adminEmail = email ?? '';
      });
    } catch (e) {
      print('Error loading admin data: $e');
    }
  }

  Future<void> _loadRecipes() async {
    setState(() => isLoading = true);
    try {
      print('Starting to load recipes...');

      final results = await DatabaseHelper.executeQuery('''
        SELECT 
          r.recipe_id,
          CONVERT(r.title USING utf8) as title,
          CONVERT(r.description USING utf8) as description,
          r.cooking_time,
          CONVERT(r.difficulty_level USING utf8) as difficulty_level,
          CONVERT(r.cuisine_type USING utf8) as cuisine_type,
          CONVERT(IFNULL(r.image_url, '') USING utf8) as image_url,
          CONVERT(IFNULL(r.video_url, '') USING utf8) as video_url,
          r.created_at,
          GROUP_CONCAT(DISTINCT i.name) as ingredients
        FROM recipes r 
        LEFT JOIN recipe_ingredients ri ON r.recipe_id = ri.recipe_id 
        LEFT JOIN ingredients i ON ri.ingredient_id = i.ingredient_id 
        GROUP BY r.recipe_id 
        ORDER BY r.created_at DESC
      ''');

      setState(() {
        recipes = results.map((row) {
          var fields = Map<String, dynamic>.from(row.fields);
          print('Recipe data: $fields');
          return fields;
        }).toList();
      });

      print('Loaded ${recipes.length} recipes');
    } catch (e) {
      print('Error loading recipes: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load recipes: $e'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

    Future<void> _editRecipe(Map<String, dynamic> recipe) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RecipeDialog(recipe: recipe),
    );

    if (result != null) {
      setState(() => isLoading = true);
      try {
        String? imageUrl = result['image_url'];
        
        await DatabaseHelper.executeQuery(
          '''UPDATE recipes 
             SET title = ?, 
                 description = ?, 
                 cooking_time = ?, 
                 difficulty_level = ?, 
                 cuisine_type = ?, 
                 video_url = ?,
                 image_url = ?
             WHERE recipe_id = ?''',
          [
            result['title'],
            result['description'],
            result['cooking_time'],
            result['difficulty_level'],
            result['cuisine_type'],
            result['video_url'],
            imageUrl,
            recipe['recipe_id'],
          ]
        );

        await DatabaseHelper.executeQuery(
          'DELETE FROM recipe_ingredients WHERE recipe_id = ?',
          [recipe['recipe_id']]
        );

        List<String> ingredients = result['ingredients'].toString().split(',');
        for (String ingredient in ingredients) {
          ingredient = ingredient.trim();
          if (ingredient.isNotEmpty) {
            await DatabaseHelper.executeQuery(
              'INSERT IGNORE INTO ingredients (name) VALUES (?)',
              [ingredient]
            );

            var ingredientResult = await DatabaseHelper.executeQuery(
              'SELECT ingredient_id FROM ingredients WHERE name = ?',
              [ingredient]
            );

            if (ingredientResult.isNotEmpty) {
              await DatabaseHelper.executeQuery(
                'INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity) VALUES (?, ?, ?)',
                [recipe['recipe_id'], ingredientResult.first['ingredient_id'], '1 unit']
              );
            }
          }
        }

        await _loadRecipes();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe updated successfully!'),
            backgroundColor: Colors.green,
          )
        );
      } catch (e) {
        print('Error updating recipe: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update recipe: $e'),
            backgroundColor: Colors.red,
          )
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addRecipe() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const RecipeDialog(),
    );

    if (result != null) {
      setState(() => isLoading = true);
      try {
        var recipeResult = await DatabaseHelper.executeQuery(
          '''INSERT INTO recipes 
             (title, description, cooking_time, difficulty_level, cuisine_type, video_url, image_url)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            result['title'],
            result['description'],
            result['cooking_time'],
            result['difficulty_level'],
            result['cuisine_type'],
            result['video_url'],
            result['image_url'],
          ]
        );

        int recipeId = recipeResult.insertId!;

        List<String> ingredients = result['ingredients'].toString().split(',');
        for (String ingredient in ingredients) {
          ingredient = ingredient.trim();
          if (ingredient.isNotEmpty) {
            await DatabaseHelper.executeQuery(
              'INSERT IGNORE INTO ingredients (name) VALUES (?)',
              [ingredient]
            );

            var ingredientResult = await DatabaseHelper.executeQuery(
              'SELECT ingredient_id FROM ingredients WHERE name = ?',
              [ingredient]
            );

            if (ingredientResult.isNotEmpty) {
              await DatabaseHelper.executeQuery(
                'INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity) VALUES (?, ?, ?)',
                [recipeId, ingredientResult.first['ingredient_id'], '1 unit']
              );
            }
          }
        }

        await _loadRecipes();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe added successfully!'),
            backgroundColor: Colors.green,
          )
        );
      } catch (e) {
        print('Error adding recipe: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add recipe: $e'),
            backgroundColor: Colors.red,
          )
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

    Future<void> _deleteRecipe(int recipeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);
      try {
        await DatabaseHelper.executeQuery(
          'DELETE FROM recipe_ingredients WHERE recipe_id = ?',
          [recipeId]
        );
        
        await DatabaseHelper.executeQuery(
          'DELETE FROM recipes WHERE recipe_id = ?',
          [recipeId]
        );
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe deleted successfully!'),
            backgroundColor: Colors.green,
          )
        );
        
        await _loadRecipes();
      } catch (e) {
        print('Error deleting recipe: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete recipe: $e'),
            backgroundColor: Colors.red,
          )
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Recipes'),
      ),
      drawer: AdminDrawer(adminEmail: adminEmail),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recipes found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: recipes.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (recipe['image_url'] != null && 
                              recipe['image_url'].toString().isNotEmpty)
                            Container(
                              height: 200,
                              width: double.infinity,
                              child: recipe['image_url'].toString().startsWith('http')
                                  ? Image.network(
                                      recipe['image_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Error loading network image: $error');
                                        return _buildImagePlaceholder();
                                      },
                                    )
                                  : Image.file(
                                      File(recipe['image_url']),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Error loading local image: $error');
                                        return _buildImagePlaceholder();
                                      },
                                    ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        recipe['title']?.toString() ?? 'No title',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editRecipe(recipe),
                                          tooltip: 'Edit Recipe',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red,
                                          onPressed: () => _deleteRecipe(recipe['recipe_id']),
                                          tooltip: 'Delete Recipe',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  recipe['description']?.toString() ?? 'No description',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined, 
                                         size: 20, 
                                         color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${recipe['cooking_time'] ?? 0} mins',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(width: 24),
                                    Icon(Icons.restaurant_menu, 
                                         size: 20, 
                                         color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      recipe['difficulty_level']?.toString() ?? 'Easy',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                if (recipe['ingredients'] != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Ingredients:',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    recipe['ingredients'].toString(),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecipe,
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant,
            size: 50,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class RecipeDialog extends StatefulWidget {
  final Map<String, dynamic>? recipe;

  const RecipeDialog({Key? key, this.recipe}) : super(key: key);

  @override
  State<RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<RecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cookingTimeController = TextEditingController();
  final _videoUrlController = TextEditingController();
  String _selectedDifficulty = 'Easy';
  String _selectedCuisine = 'Italian';
  File? _imageFile;
  String? _imageUrl;

  final List<Map<String, TextEditingController>> _ingredientControllers = [];

  final List<String> _difficultyLevels = ['Easy', 'Medium', 'Hard'];
  final List<String> _cuisineTypes = [
    'Italian', 'Chinese', 'Indian', 'Mexican', 'Japanese', 'Thai', 'French'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _titleController.text = widget.recipe!['title']?.toString() ?? '';
      _descriptionController.text = widget.recipe!['description']?.toString() ?? '';
      _cookingTimeController.text = widget.recipe!['cooking_time']?.toString() ?? '';
      _videoUrlController.text = widget.recipe!['video_url']?.toString() ?? '';
      _selectedDifficulty = widget.recipe!['difficulty_level']?.toString() ?? 'Easy';
      _selectedCuisine = widget.recipe!['cuisine_type']?.toString() ?? 'Italian';
      _imageUrl = widget.recipe!['image_url'];
      
      if (widget.recipe!['ingredients'] != null) {
        final ingredients = widget.recipe!['ingredients'].toString().split(',');
        for (var ingredient in ingredients) {
          _addIngredientField(ingredient.trim());
        }
      }
    }
    
    if (_ingredientControllers.isEmpty) {
      _addIngredientField();
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageUrl = pickedFile.path;
        });
        print('Image picked: ${pickedFile.path}');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _addIngredientField([String? ingredient]) {
    setState(() {
      _ingredientControllers.add({
        'name': TextEditingController(text: ingredient ?? ''),
        'quantity': TextEditingController(text: '1 unit'),
      });
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      _ingredientControllers[index]['name']?.dispose();
      _ingredientControllers[index]['quantity']?.dispose();
      _ingredientControllers.removeAt(index);
    });
  }

  String _getIngredientsWithQuantities() {
    return _ingredientControllers
        .where((controllers) => controllers['name']!.text.isNotEmpty)
        .map((controllers) => 
            '${controllers['name']!.text} (${controllers['quantity']!.text})')
        .join(', ');
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: 50,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 8),
        Text(
          'Add Image',
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.recipe == null ? 'Add Recipe' : 'Edit Recipe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : _imageUrl != null && _imageUrl!.isNotEmpty
                            ? _imageUrl!.startsWith('http')
                                ? Image.network(
                                    _imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildImagePlaceholder();
                                    },
                                  )
                                : Image.file(
                                    File(_imageUrl!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildImagePlaceholder();
                                    },
                                  )
                            : _buildImagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cookingTimeController,
                  decoration: const InputDecoration(labelText: 'Cooking Time (minutes)'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDifficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty Level'),
                  items: _difficultyLevels.map((level) {
                    return DropdownMenuItem(value: level, child: Text(level));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedDifficulty = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCuisine,
                  decoration: const InputDecoration(labelText: 'Cuisine Type'),
                  items: _cuisineTypes.map((cuisine) {
                    return DropdownMenuItem(value: cuisine, child: Text(cuisine));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCuisine = value!),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredients',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._ingredientControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      var controllers = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: controllers['name'],
                                decoration: const InputDecoration(
                                  labelText: 'Ingredient',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: controllers['quantity'],
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle),
                              onPressed: () => _removeIngredientField(index),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    ElevatedButton.icon(
                      onPressed: () => _addIngredientField(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Ingredient'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _videoUrlController,
                  decoration: const InputDecoration(labelText: 'Video URL (optional)'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'title': _titleController.text,
                            'description': _descriptionController.text,
                            'cooking_time': int.parse(_cookingTimeController.text),
                            'difficulty_level': _selectedDifficulty,
                            'cuisine_type': _selectedCuisine,
                            'ingredients': _getIngredientsWithQuantities(),
                            'video_url': _videoUrlController.text,
                            'image_url': _imageUrl,
                          });
                        }
                      },
                      child: Text(widget.recipe == null ? 'Add Recipe' : 'Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cookingTimeController.dispose();
    _videoUrlController.dispose();
    for (var controllers in _ingredientControllers) {
      controllers['name']?.dispose();
      controllers['quantity']?.dispose();
    }
    super.dispose();
  }
}