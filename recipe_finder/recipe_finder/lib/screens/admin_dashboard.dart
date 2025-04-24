// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import '../utils/session_manager.dart';
import '../database/database_helper.dart';
import '../widgets/admin_drawer.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String adminEmail = '';
  Map<String, int> stats = {
    'recipes': 0,
    'users': 0,
    'videos': 0,
  };
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _loadStats();
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

  Future<void> _loadStats() async {
    setState(() => isLoading = true);
    try {
      final recipeCount = await DatabaseHelper.executeQuery(
        'SELECT COUNT(*) as count FROM recipes'
      );
      final userCount = await DatabaseHelper.executeQuery(
        'SELECT COUNT(*) as count FROM users WHERE role = ?',
        ['user']
      );
      
      setState(() {
        stats['recipes'] = recipeCount.first['count'] as int;
        stats['users'] = userCount.first['count'] as int;
      });
    } catch (e) {
      print('Error loading stats: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      drawer: AdminDrawer(adminEmail: adminEmail),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Admin!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        context,
                        'Recipes',
                        stats['recipes'].toString(),
                        Icons.restaurant_menu,
                        Colors.blue,
                        () => Navigator.pushNamed(context, '/manage_recipes'),
                      ),
                      _buildStatCard(
                        context,
                        'Users',
                        stats['users'].toString(),
                        Icons.people,
                        Colors.green,
                        () {},
                      ),
                      _buildStatCard(
                        context,
                        'Videos',
                        stats['videos'].toString(),
                        Icons.video_library,
                        Colors.orange,
                        () => Navigator.pushNamed(context, '/manage_videos'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}