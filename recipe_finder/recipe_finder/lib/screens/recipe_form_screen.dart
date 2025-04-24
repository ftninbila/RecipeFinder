import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/recipe.dart';
import '../database/database_helper.dart';

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipe; // null for add, non-null for edit

  RecipeFormScreen({this.recipe});

  @override
  _RecipeFormScreenState createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cookingTimeController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _ingredientControllers = <TextEditingController>[];
  final _quantityControllers = <TextEditingController>[];
  
  String _selectedDifficulty = 'Easy';
  String _selectedCuisine = 'Italian';
  File? _imageFile;
  bool _isLoading = false;
  List<String> _availableIngredients = [];

  final List<String> _difficultyLevels = ['Easy', 'Medium', 'Hard'];
  final List<String> _cuisineTypes = [
    'Italian', 'Chinese', 'Indian', 'Mexican', 'Japanese', 'Thai', 'French'
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableIngredients();
    if (widget.recipe != null) {
      _loadRecipeData();
    } else {
      _addIngredientField();
    }
  }

  Future<void> _loadAvailableIngredients() async {
    try {
      final conn = await DatabaseHelper.getConnection();
      var results = await conn.query('SELECT name FROM ingredients ORDER BY name');
      await conn.close();

      setState(() {
        _availableIngredients = results.map((row) => row[0].toString()).toList();
      });
    } catch (e) {
      print('Error loading ingredients: $e');
    }
  }

  Future<void> _loadRecipeData() async {
    _titleController.text = widget.recipe!.title;
    _descriptionController.text = widget.recipe!.description;
    _cookingTimeController.text = widget.recipe!.cookingTime.toString();
    _videoUrlController.text = widget.recipe!.videoUrl;
    _selectedDifficulty = widget.recipe!.difficultyLevel;
    _selectedCuisine = widget.recipe!.cuisineType;

    try {
      final conn = await DatabaseHelper.getConnection();
      var results = await conn.query('''
        SELECT i.name, ri.quantity 
        FROM recipe_ingredients ri
        JOIN ingredients i ON ri.ingredient_id = i.ingredient_id
        WHERE ri.recipe_id = ?
      ''', [widget.recipe!.id]);
      await conn.close();

      for (var row in results) {
        final ingredientController = TextEditingController(text: row[0]);
        final quantityController = TextEditingController(text: row[1]);
        _ingredientControllers.add(ingredientController);
        _quantityControllers.add(quantityController);
      }
      
      if (_ingredientControllers.isEmpty) {
        _addIngredientField();
      }
    } catch (e) {
      print('Error loading recipe ingredients: $e');
    }
  }

  void _addIngredientField() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController());
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      _ingredientControllers[index].dispose();
      _quantityControllers[index].dispose();
      _ingredientControllers.removeAt(index);
      _quantityControllers.removeAt(index);
    });
  }

  Future<void> _pickImage() async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  } catch (e) {
    print('Error picking image: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to pick image'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final conn = await DatabaseHelper.getConnection();

      // Upload image and get URL (implement your own image upload logic)
      String imageUrl = _imageFile != null 
          ? await _uploadImage(_imageFile!) 
          : widget.recipe?.imageUrl ?? '';

      if (widget.recipe == null) {
        // Insert new recipe
        var result = await conn.query('''
          INSERT INTO recipes (
            title, description, cooking_time, difficulty_level, 
            cuisine_type, image_url, video_url
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [
          _titleController.text,
          _descriptionController.text,
          int.parse(_cookingTimeController.text),
          _selectedDifficulty,
          _selectedCuisine,
          imageUrl,
          _videoUrlController.text,
        ]);

        int recipeId = result.insertId!;

        // Insert ingredients
        for (int i = 0; i < _ingredientControllers.length; i++) {
          // First ensure ingredient exists
          await conn.query(
            'INSERT IGNORE INTO ingredients (name) VALUES (?)',
            [_ingredientControllers[i].text]
          );

          // Get ingredient ID
          var ingredientResult = await conn.query(
            'SELECT ingredient_id FROM ingredients WHERE name = ?',
            [_ingredientControllers[i].text]
          );

          // Insert recipe-ingredient relationship
          await conn.query('''
            INSERT INTO recipe_ingredients (
              recipe_id, ingredient_id, quantity
            ) VALUES (?, ?, ?)
          ''', [
            recipeId,
            ingredientResult.first[0],
            _quantityControllers[i].text,
          ]);
        }
      } else {
        // Update existing recipe
        await conn.query('''
          UPDATE recipes SET 
            title = ?, description = ?, cooking_time = ?,
            difficulty_level = ?, cuisine_type = ?,
            image_url = ?, video_url = ?
          WHERE recipe_id = ?
        ''', [
          _titleController.text,
          _descriptionController.text,
          int.parse(_cookingTimeController.text),
          _selectedDifficulty,
          _selectedCuisine,
          imageUrl,
          _videoUrlController.text,
          widget.recipe!.id,
        ]);

        // Delete existing ingredients
        await conn.query(
          'DELETE FROM recipe_ingredients WHERE recipe_id = ?',
          [widget.recipe!.id]
        );

        // Insert new ingredients
        for (int i = 0; i < _ingredientControllers.length; i++) {
          await conn.query(
            'INSERT IGNORE INTO ingredients (name) VALUES (?)',
            [_ingredientControllers[i].text]
          );

          var ingredientResult = await conn.query(
            'SELECT ingredient_id FROM ingredients WHERE name = ?',
            [_ingredientControllers[i].text]
          );

          await conn.query('''
            INSERT INTO recipe_ingredients (
              recipe_id, ingredient_id, quantity
            ) VALUES (?, ?, ?)
          ''', [
            widget.recipe!.id,
            ingredientResult.first[0],
            _quantityControllers[i].text,
          ]);
        }
      }

      await conn.close();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recipe saved successfully')),
      );
    } catch (e) {
      print('Error saving recipe: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving recipe')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Implement your own image upload logic
  Future<String> _uploadImage(File imageFile) async {
  try {
    // For now, we'll just return the local path
    // In a production app, you would upload this to a server
    return imageFile.path;
  } catch (e) {
    print('Error uploading image: $e');
    return '';
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Add Recipe' : 'Edit Recipe'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
  onTap: _pickImage,
  child: Container(
    height: 200,
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(8),
    ),
    child: _imageFile != null
        ? Image.file(
            _imageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading image file: $error');
              return const Icon(Icons.broken_image, size: 50);
            },
          )
        : widget.recipe?.imageUrl != null && widget.recipe!.imageUrl.isNotEmpty
            ? widget.recipe!.imageUrl.startsWith('http')
                ? Image.network(
                    widget.recipe!.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading network image: $error');
                      return const Icon(Icons.broken_image, size: 50);
                    },
                  )
                : Image.file(
                    File(widget.recipe!.imageUrl),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading local image: $error');
                      return const Icon(Icons.broken_image, size: 50);
                    },
                  )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_photo_alternate, size: 50),
                  SizedBox(height: 8),
                  Text('Add Image'),
                ],
              ),
  ),
),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Recipe Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cookingTimeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Cooking Time (minutes)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter cooking time';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedDifficulty,
                            decoration: InputDecoration(
                              labelText: 'Difficulty',
                              border: OutlineInputBorder(),
                            ),
                            items: _difficultyLevels.map((String difficulty) {
                              return DropdownMenuItem(
                                value: difficulty,
                                child: Text(difficulty),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDifficulty = newValue!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCuisine,
                      decoration: InputDecoration(
                        labelText: 'Cuisine Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _cuisineTypes.map((String cuisine) {
                        return DropdownMenuItem(
                          value: cuisine,
                          child: Text(cuisine),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCuisine = newValue!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _videoUrlController,
                      decoration: InputDecoration(
                        labelText: 'Video Tutorial URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _ingredientControllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Autocomplete<String>(
                                  initialValue: TextEditingValue(
                                    text: _ingredientControllers[index].text,
                                  ),
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text == '') {
                                      return const Iterable<String>.empty();
                                    }
                                    return _availableIngredients.where((String option) {
                                      return option.toLowerCase()
                                          .contains(textEditingValue.text.toLowerCase());
                                    });
                                  },
                                  onSelected: (String selection) {
                                    _ingredientControllers[index].text = selection;
                                  },
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    _ingredientControllers[index] = controller;
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Ingredient',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter an ingredient';
                                        }
                                        return null;
                                      },
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantityControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter quantity';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle),
                                onPressed: () => _removeIngredientField(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: _addIngredientField,
                      icon: Icon(Icons.add),
                      label: Text('Add Ingredient'),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveRecipe,
                      child: Text('Save Recipe'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
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
    for (var controller in _ingredientControllers) {
      controller.dispose();
    }
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}