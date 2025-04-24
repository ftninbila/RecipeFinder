import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/favorites_screen.dart'; // Add this import
import 'screens/manage_recipes_screen.dart';
import 'screens/manage_videos_screen.dart';
import 'models/recipe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.blue.shade300,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade300,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade300,
              width: 2,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SplashScreen();
            }

            final prefs = snapshot.data!;
            final isLoggedIn = prefs.containsKey('user_id');
            final role = prefs.getString('role');

            if (!isLoggedIn) {
              return const LoginScreen();
            }

            return role == 'admin' 
              ? const AdminDashboard() 
              : const HomeScreen();
          },
        ),
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/admin_dashboard': (context) => const AdminDashboard(),
        '/register': (context) => const RegisterScreen(),
        '/manage_recipes': (context) => const ManageRecipesScreen(),
        '/manage_videos': (context) => const ManageVideosScreen(),
        '/favorites': (context) => const FavoritesScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/recipe-detail') {
          final Recipe? recipe = settings.arguments as Recipe?;
          if (recipe != null) {
            return MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipe: recipe),
            );
          }
        }
        // Return a 404 page if the route or arguments are invalid
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Page not found')),
          ),
        );
      },
      builder: (context, widget) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorDetails.exception.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        };
        return widget!;
      },
    );
  }
}