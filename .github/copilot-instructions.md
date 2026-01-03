# Copilot Instructions for Agora

## Project Overview
- **Agora** is a Flutter app for crowdsourcing information about study places in Athens.
- The app uses Firebase (Auth, Firestore), Google Maps, and local storage (SharedPreferences).
- Main features: user authentication, place discovery, reviews, favorites, theming, and offline support.

## Architecture & Key Patterns
- **Entry point:** `lib/main.dart` initializes environment, Firebase, and managers.
- **Navigation:** Managed via `lib/pages/main_navigation.dart` (bottom navigation, page switching).
- **State management:** Uses `provider` for app-wide state (see `ThemeManager`, `FavoritesManager`).
- **Services:**
  - `lib/services/auth_service.dart`: Handles user auth and Firestore user docs.
  - `lib/services/database_service.dart`: CRUD for places, reviews, and favorites (Firestore).
  - `lib/services/favorites_manager.dart`: Syncs favorites between Firestore and local storage.
  - `lib/services/theme_manager.dart`: Persists and manages theme mode.
- **Models:**
  - `lib/models/study_place.dart`, `lib/models/review.dart`, `lib/models/user.dart`.
- **Pages:**
  - All UI pages in `lib/pages/` (e.g., `home_page.dart`, `favorites_page.dart`, `profile_page.dart`).

## Developer Workflows
- **Build:**
  - `flutter pub get` to fetch dependencies.
  - `flutter run` to launch the app (multi-platform: Android, iOS, web, desktop).
- **Test:**
  - `flutter test` runs all tests in `test/`.
- **Firebase:**
  - Requires valid `google-services.json` (Android) and Firebase setup.
- **Environment:**
  - Uses `.env` file (managed by `flutter_dotenv`).
- **Theming:**
  - Theme is persisted via `ThemeManager` and `SharedPreferences`.
- **Favorites:**
  - Synced to Firestore if logged in, else stored locally.

## Conventions & Patterns
- **Error handling:**
  - Service classes wrap and rethrow errors with user-friendly messages.
- **Initialization:**
  - All async setup is in `main()` before `runApp()`.
- **Provider:**
  - Use `ChangeNotifierProvider` for stateful managers.
- **Firestore:**
  - User data is namespaced under `users/{uid}/...`.
- **Offline support:**
  - Favorites fallback to local storage if not authenticated or on error.

## Integration Points
- **Firebase:** Auth, Firestore, and platform-specific configs.
- **Google Maps:** Requires API keys and correct setup in `android/`, `ios/`, and `web/`.

## References
- See `lib/main.dart` for app bootstrapping.
- See `lib/services/` for business logic and data access.
- See `pubspec.yaml` for dependencies.
- See `README.md` for high-level project info.

---
_Keep instructions concise and up-to-date. Update this file if project structure or workflows change._
