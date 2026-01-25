import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../chat/conversations_screen.dart';
import '../learn/lessons_list_screen.dart';
import '../videos/videos_feed_screen.dart';
import '../shop/products_list_screen.dart';
import '../games/games_list_screen.dart';
import '../sports/sports_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ConversationsScreen(),
    LessonsListScreen(),
    VideosFeedScreen(),
    ShopScreen(),
    SportsScreen(),
    GamesListScreen(),
    ProfileScreenTab(), // Profil ca tab
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: context.tr('nav_chat'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: context.tr('nav_learn'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.play_circle_outline),
            selectedIcon: const Icon(Icons.play_circle),
            label: context.tr('nav_videos'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: context.tr('nav_shop'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: const Icon(Icons.sports_soccer),
            label: context.tr('nav_sports'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_esports_outlined),
            selectedIcon: const Icon(Icons.sports_esports),
            label: context.tr('nav_games'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.tr('profile'),
          ),
        ],
      ),
    );
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductsListScreen();
  }
}

/// Wrapper pentru ProfileScreen ca tab (fără AppBar back button)
class ProfileScreenTab extends StatelessWidget {
  const ProfileScreenTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}