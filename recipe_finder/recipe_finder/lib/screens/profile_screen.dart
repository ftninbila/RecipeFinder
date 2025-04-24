import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = true;
  int _totalFavorites = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final conn = await DatabaseHelper.getConnection();
      var userResults = await conn.query(
        'SELECT username, email FROM users WHERE user_id = ?',
        [1], // Replace with actual user_id from session
      );

      var favoriteResults = await conn.query(
        'SELECT COUNT(*) as total FROM favorites WHERE user_id = ?',
        [1], // Replace with actual user_id
      );

      await conn.close();

      if (userResults.isNotEmpty) {
        setState(() {
          _usernameController.text = userResults.first['username'];
          _emailController.text = userResults.first['email'];
          _totalFavorites = favoriteResults.first['total'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final conn = await DatabaseHelper.getConnection();
      
      // Update basic info
      await conn.query(
        'UPDATE users SET username = ?, email = ? WHERE user_id = ?',
        [_usernameController.text, _emailController.text, 1], // Replace with actual user_id
      );

      // Update password if provided
      if (_currentPasswordController.text.isNotEmpty && 
          _newPasswordController.text.isNotEmpty) {
        // Verify current password
        var passwordCheck = await conn.query(
          'SELECT password FROM users WHERE user_id = ?',
          [1], // Replace with actual user_id
        );

        if (passwordCheck.first['password'] == _currentPasswordController.text) {
          await conn.query(
            'UPDATE users SET password = ? WHERE user_id = ?',
            [_newPasswordController.text, 1], // Replace with actual user_id
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Current password is incorrect')),
          );
          return;
        }
      }

      await conn.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // Implement logout functionality
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.orange[200],
                          child: Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _usernameController.text,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _emailController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  // Stats Card
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                _totalFavorites.toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Favorite Recipes'),
                            ],
                          ),
                          // Add more stats here if needed
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Edit Profile Form
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a username';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty && value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _updateProfile,
                              child: Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}