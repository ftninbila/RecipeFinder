// lib/screens/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../database/database_helper.dart';
import '../utils/session_manager.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isFavorite = false;
  bool _isLoading = false;

  @override
void initState() {
  super.initState();
  _checkLoginAndFavoriteStatus();
}

Future<void> _checkLoginAndFavoriteStatus() async {
  final isLoggedIn = await SessionManager.isLoggedIn();
  final userId = await SessionManager.getUserId();
  print('InitState - IsLoggedIn: $isLoggedIn');
  print('InitState - UserId: $userId');
  _checkIfFavorite();
}

  Future<void> _checkIfFavorite() async {
    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) return;

      final results = await DatabaseHelper.executeQuery(
        'SELECT * FROM favorites WHERE user_id = ? AND recipe_id = ?',
        [userId, widget.recipe.id]
      );

      if (mounted) {
        setState(() {
          _isFavorite = results.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
  setState(() => _isLoading = true);
  try {
    // First check if user is logged in
    final isLoggedIn = await SessionManager.isLoggedIn();
    print('Is user logged in? $isLoggedIn'); // Debug print

    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add favorites'),
          backgroundColor: Colors.orange,
        )
      );
      // Optionally navigate to login screen
      Navigator.pushNamed(context, '/login');
      return;
    }

    final userId = await SessionManager.getUserId();
    print('Current userId: $userId'); // Debug print

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add favorites'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    if (_isFavorite) {
      await DatabaseHelper.executeQuery(
        'DELETE FROM favorites WHERE user_id = ? AND recipe_id = ?',
        [userId, widget.recipe.id]
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites'))
      );
    } else {
      print('Adding favorite - userId: $userId, recipeId: ${widget.recipe.id}'); // Debug print
      await DatabaseHelper.executeQuery(
        'INSERT INTO favorites (user_id, recipe_id) VALUES (?, ?)',
        [userId, widget.recipe.id]
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to favorites'))
      );
    }

    setState(() {
      _isFavorite = !_isFavorite;
    });
  } catch (e) {
    print('Error toggling favorite: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating favorites: $e'))
    );
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _launchVideoUrl() async {
    if (widget.recipe.videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No video tutorial available'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    final Uri url = Uri.parse(widget.recipe.videoUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch video URL'),
            backgroundColor: Colors.red,
          )
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching video: $e'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.title),
        actions: [
          _isLoading
              ? const SizedBox(
                  width: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : null,
                  ),
                  onPressed: _toggleFavorite,
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            if (widget.recipe.imageUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 250,
                child: widget.recipe.imageUrl.startsWith('http')
                    ? Image.network(
                        widget.recipe.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading network image: $error');
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.restaurant,
                              size: 64,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Image.file(
                        File(widget.recipe.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading local image: $error');
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.restaurant,
                              size: 64,
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
                  // Title and Description
                  Text(
                    widget.recipe.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.recipe.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),

                  // Recipe Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.recipe.cookingTime} mins',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.recipe.cuisineType,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.speed,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.recipe.difficultyLevel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ingredients Section
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.recipe.ingredients.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.recipe.ingredients.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fiber_manual_record,
                                size: 8,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.recipe.ingredients[index],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    Text(
                      'No ingredients listed',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),

                  // Video Tutorial Section
                  if (widget.recipe.videoUrl.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Video Tutorial',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _launchVideoUrl,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Watch Video Tutorial'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}