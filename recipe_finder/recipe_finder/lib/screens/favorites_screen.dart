import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/session_manager.dart';
import '../models/recipe.dart';
import 'dart:io';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Recipe> _favorites = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  String _convertToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List<int>) return String.fromCharCodes(value);
    return value.toString();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final results = await DatabaseHelper.executeQuery('''
        SELECT r.* 
        FROM recipes r 
        INNER JOIN favorites f ON r.recipe_id = f.recipe_id 
        WHERE f.user_id = ?
        ORDER BY f.created_at DESC
      ''', [userId]);

      setState(() {
        _favorites = results.map((row) {
          // Convert the row fields to a new map with string values
          Map<String, dynamic> convertedFields = {};
          row.fields.forEach((key, value) {
            if (key == 'recipe_id' || key == 'cooking_time') {
              convertedFields[key] = value; // Keep numeric values as is
            } else {
              convertedFields[key] = _convertToString(value);
            }
          });
          return Recipe.fromMap(convertedFields);
        }).toList();
      });
    } catch (e) {
      print('Error loading favorites: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading favorites: $e'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No favorites yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _favorites.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final recipe = _favorites[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: recipe.imageUrl.isNotEmpty
                              ? Image.network(
                                  recipe.imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.restaurant),
                                    );
                                  },
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.restaurant),
                                ),
                        ),
                        title: Text(
                          recipe.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, 
                                     size: 16, 
                                     color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text('${recipe.cookingTime} mins'),
                                const SizedBox(width: 16),
                                Icon(Icons.restaurant_menu, 
                                     size: 16, 
                                     color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(recipe.difficultyLevel),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/recipe-detail',
                            arguments: recipe,
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}