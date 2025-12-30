import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_page.dart';
import 'pages/main_navigation.dart';
import 'services/favorites_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // Initialize favorites manager to load saved favorites
  await FavoritesManager().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _username;

  void _handleLogin(String username) {
    setState(() {
      _username = username;
    });
  }

  void _handleLogout() {
    setState(() {
      _username = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: _username == null
          ? LoginPage(onLogin: _handleLogin)
          : MainNavigation(onLogout: _handleLogout, username: _username!),
    );
  }
}

