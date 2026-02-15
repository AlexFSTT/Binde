import 'package:flutter/material.dart';

/// Bottom Navigation Bar cu 5 items vizibile + hamburger menu
/// Items: Chat, Learn,Shop, Sports, More (hamburger)
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.6),
      selectedFontSize: 12,
      unselectedFontSize: 12,
      elevation: 8,
      items: const [
        // Chat
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          activeIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        
        // Learn
        BottomNavigationBarItem(
          icon: Icon(Icons.school_outlined),
          activeIcon: Icon(Icons.school),
          label: 'Learn',
        ),
        
        // Shop
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_outlined),
          activeIcon: Icon(Icons.shopping_bag),
          label: 'Shop',
        ),
        
        // Sports
        BottomNavigationBarItem(
          icon: Icon(Icons.sports_soccer_outlined),
          activeIcon: Icon(Icons.sports_soccer),
          label: 'Sports',
        ),
        
        // More (Hamburger Menu)
        BottomNavigationBarItem(
          icon: Icon(Icons.menu),
          activeIcon: Icon(Icons.menu_open),
          label: 'More',
        ),
      ],
    );
  }
}
