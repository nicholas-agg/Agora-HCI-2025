import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'pages/main_navigation.dart';
import 'services/favorites_manager.dart';
import 'services/theme_manager.dart';
import 'services/auth_service.dart';
import 'package:provider/provider.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force the Latest Renderer to support Cloud Map IDs
  final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    try {
      await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
      debugPrint('Maps renderer initialized: latest');
    } catch (e) {
      // Renderer already initialized (happens on hot restart)
      debugPrint('Maps renderer already initialized: $e');
    }
  }

  try {
    // Load environment variables
    await dotenv.load();
    
    // Initialize Firebase with error handling
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize favorites manager to load saved favorites
    await FavoritesManager().initialize();
  } catch (e) {
    debugPrint('Initialization error: $e');
    // Continue running the app even if some initialization fails
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    return MaterialApp(
      title: 'Agora',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeManager.themeMode,
      home: StreamBuilder(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          // Show error screen if there's a connection error
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Connection Error',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check your internet connection and restart the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          // Show loading screen while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // If user is logged in AND email is verified, show main navigation
          if (snapshot.hasData && snapshot.data != null) {
            // Check if email is verified
            if (snapshot.data!.emailVerified) {
              return MainNavigation(
                onLogout: () async {
                  await _authService.signOut();
                },
                username: snapshot.data!.displayName ?? snapshot.data!.email ?? 'User',
              );
            } else {
              // User is signed in but email not verified - sign them out and show login
              _authService.signOut();
              return const LoginPage();
            }
          }
          
          // Otherwise, show login page
          return const LoginPage();
        },
      ),
    );
  }
}

