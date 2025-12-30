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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      MyHomePage(
        onLogout: widget.onLogout,
        username: widget.username,
      ),
      const FavoritesPage(),
      ProfilePage(onSignOut: widget.onLogout),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0),
            _buildNavItem(Icons.bookmark, 'Favorites', 1),
            _buildNavItem(Icons.person, 'Profile', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
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
                color: isActive ? const Color(0xFFEADDFF) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive 
                  ? (index == 0 ? Icons.home : index == 1 ? Icons.bookmark : Icons.person)
                  : (index == 0 ? Icons.home_outlined : index == 1 ? Icons.bookmark_border : Icons.person_outline),
                color: isActive ? const Color(0xFF21005D) : const Color(0xFF49454F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF1D1B20) : const Color(0xFF49454F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
