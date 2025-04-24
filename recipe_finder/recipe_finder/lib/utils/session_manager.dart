import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'email';
  static const String _roleKey = 'role';

  static Future<void> saveUserSession(
    int userId,
    String email,
    String role,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId.toString());
      await prefs.setString(_emailKey, email);
      await prefs.setString(_roleKey, role);
      
      // Debug prints
      print('Saving session:');
      print('userId: $userId');
      print('email: $email');
      print('role: $role');
    } catch (e) {
      print('Error saving session: $e');
      throw Exception('Failed to save session: $e');
    }
  }

  static Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userIdString = prefs.getString(_userIdKey);
      print('Retrieved userId from prefs: $userIdString'); // Debug print
      
      if (userIdString == null || userIdString.isEmpty) {
        return null;
      }
      
      return int.parse(userIdString);
    } catch (e) {
      print('Error getting userId: $e');
      return null;
    }
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<bool> isLoggedIn() async {
    final userId = await getUserId();
    return userId != null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
  }

  static Future<void> setEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    return role == 'admin';
  }
}