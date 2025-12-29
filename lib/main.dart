import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_page.dart';
import 'pages/home_page.dart';

void main() async {
  await dotenv.load();
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
          : MyHomePage(onLogout: _handleLogout, username: _username!),
    );
  }
}

