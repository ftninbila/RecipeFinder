import 'package:flutter/material.dart';
import '../utils/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'Spanish', 'French', 'German'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
    await prefs.setString('selected_language', _selectedLanguage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Account'),
            leading: Icon(Icons.person),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          Divider(),
          SwitchListTile(
            title: Text('Push Notifications'),
            subtitle: Text('Receive recipe recommendations'),
            secondary: Icon(Icons.notifications),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
                _saveSettings();
              });
            },
          ),
          SwitchListTile(
            title: Text('Dark Mode'),
            subtitle: Text('Enable dark theme'),
            secondary: Icon(Icons.dark_mode),
            value: _darkModeEnabled,
            onChanged: (bool value) {
              setState(() {
                _darkModeEnabled = value;
                _saveSettings();
              });
            },
          ),
          ListTile(
            title: Text('Language'),
            leading: Icon(Icons.language),
            trailing: DropdownButton<String>(
              value: _selectedLanguage,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedLanguage = newValue;
                    _saveSettings();
                  });
                }
              },
              items: _languages.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Divider(),
          ListTile(
            title: Text('About'),
            leading: Icon(Icons.info),
            onTap: () {
              _showAboutDialog();
            },
          ),
          ListTile(
            title: Text('Privacy Policy'),
            leading: Icon(Icons.privacy_tip),
            onTap: () {
              // Navigate to privacy policy
            },
          ),
          ListTile(
            title: Text('Terms of Service'),
            leading: Icon(Icons.description),
            onTap: () {
              // Navigate to terms of service
            },
          ),
          Divider(),
          ListTile(
            title: Text('Logout'),
            leading: Icon(Icons.logout),
            onTap: () {
              _showLogoutDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('About Recipe Finder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version: 1.0.0'),
              SizedBox(height: 8),
              Text('Developed by: Your Name'),
              SizedBox(height: 8),
              Text('Recipe Finder helps you discover delicious recipes based on ingredients you have.'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Logout'),
              onPressed: () async {
                await SessionManager.clearSession();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }
}