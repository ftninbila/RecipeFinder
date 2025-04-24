import 'package:flutter/material.dart';
import '../utils/session_manager.dart';

class AdminDrawer extends StatelessWidget {
  final String adminEmail;

  const AdminDrawer({Key? key, required this.adminEmail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.admin_panel_settings, size: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  'Admin Panel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  adminEmail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/admin_dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Manage Recipes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/manage_recipes');
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Manage Videos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/manage_videos');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await SessionManager.clearSession();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}