import 'package:flutter/material.dart';
import 'home_page.dart';
import 'favorites_page.dart';
import 'profile_page.dart';

class MainNavigation extends StatefulWidget {
  final VoidCallback onLogout;
  final String username;
  
  const MainNavigation({
    super.key,
    required this.onLogout,
    required this.username,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  GlobalKey<State<StatefulWidget>> _profilePageKey = GlobalKey();

  late List<Widget> _pages;

  void _goHome() {
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      MyHomePage(
        onLogout: widget.onLogout,
        username: widget.username,
      ),
      FavoritesPage(onLogout: widget.onLogout),
      ProfilePage(key: _profilePageKey, onSignOut: widget.onLogout, onBackToHome: _goHome),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      // If profile tab is tapped, recreate with new key to force reload
      if (index == 2) {
        _profilePageKey = GlobalKey();
        _pages[2] = ProfilePage(
          key: _profilePageKey,
          onSignOut: widget.onLogout,
          onBackToHome: _goHome,
        );
      }
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withAlpha((0.05 * 255).round()),
                blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0, colorScheme),
            _buildNavItem(Icons.bookmark, 'Favorites', 1, colorScheme),
            _buildNavItem(Icons.person, 'Profile', 2, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? colorScheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive 
                  ? (index == 0 ? Icons.home : index == 1 ? Icons.bookmark : Icons.person)
                  : (index == 0 ? Icons.home_outlined : index == 1 ? Icons.bookmark_border : Icons.person_outline),
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
