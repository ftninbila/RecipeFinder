// lib/database/database_helper.dart
import 'package:mysql1/mysql1.dart';

class DatabaseHelper {
  static Future<MySqlConnection> getConnection() async {
    try {
      final settings = ConnectionSettings(
        host: '10.0.2.2', // Use this for Android emulator
        port: 3306,
        user: 'root',
        db: 'recipe_finder'
      );
      
      print('Attempting database connection...');
      return await MySqlConnection.connect(settings);
    } catch (e) {
      print('Database connection error: $e');
      throw Exception('Failed to connect to database: $e');
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final conn = await getConnection();
      await conn.query('SELECT 1');
      await conn.close();
      print('Database connection test successful');
      return true;
    } catch (e) {
      print('Database connection test failed: $e');
      return false;
    }
  }

  static Future<Results> executeQuery(String query, [List<Object?>? params]) async {
    MySqlConnection? conn;
    try {
      conn = await getConnection();
      print('Executing query: $query');
      print('With parameters: $params');
      final results = await conn.query(query, params);
      print('Query returned ${results.length} rows');
      return results;
    } catch (e) {
      print('Query execution error: $e');
      throw Exception('Failed to execute query: $e');
    } finally {
      await conn?.close();
    }
  } 
}

