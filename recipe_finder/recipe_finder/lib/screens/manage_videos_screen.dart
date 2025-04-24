// lib/screens/manage_videos_screen.dart
import 'package:flutter/material.dart';
import '../utils/session_manager.dart';
import '../widgets/admin_drawer.dart';

class ManageVideosScreen extends StatefulWidget {
  const ManageVideosScreen({Key? key}) : super(key: key);

  @override
  State<ManageVideosScreen> createState() => _ManageVideosScreenState();
}

class _ManageVideosScreenState extends State<ManageVideosScreen> {
  String adminEmail = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Videos'),
      ),
      drawer: AdminDrawer(adminEmail: adminEmail),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Video Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video upload feature coming soon!'),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}