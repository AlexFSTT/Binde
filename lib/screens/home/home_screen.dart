import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/hamburger_menu.dart';
import '../chat/conversations_screen.dart';
import '../learn/lessons_list_screen.dart';
import '../swirls/swirls_feed_screen.dart';  // ✅ RENAMED from videos
import '../shop/products_list_screen.dart';
import '../sports/sports_screen.dart';
// ✅ REMOVED: games import
// ✅ REMOVED: profile import (now in hamburger menu)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // ✅ GlobalKey pentru a deschide drawer-ul
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ✅ UPDATED: 5 screens (fără Games și Profile)
  // Profile e acum în hamburger menu, nu în bottom nav
  final List<Widget> _screens = const [
    ConversationsScreen(),     // 0 - Chat
    LessonsListScreen(),       // 1 - Learn
    SwirlsFeedScreen(),        // 2 - Swirls (renamed from Videos)
    ShopScreen(),              // 3 - Shop
    SportsScreen(),            // 4 - Sports
    // Index 5 = Hamburger menu (nu e screen, deschide drawer)
  ];

  void _onNavigationTap(int index) {
    if (index == 5) {
      // ✅ Hamburger menu - deschide drawer
      _scaffoldKey.currentState?.openDrawer();
    } else {
      // ✅ Normal navigation
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      
      // ✅ ADDED: Hamburger drawer cu Updates, Profile, Tools
      drawer: const HamburgerMenu(),
      
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      
      // ✅ UPDATED: 5 items + hamburger (6 total)
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigationTap,  // ✅ Custom handler pentru hamburger
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          // Chat
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: context.tr('nav_chat'),
          ),
          
          // Learn
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: context.tr('nav_learn'),
          ),
          
          // Swirls (renamed from Videos)
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),  // ✅ Updated icon
            selectedIcon: const Icon(Icons.video_library),
            label: context.tr('nav_swirls'),  // ✅ Updated translation key
          ),
          
          // Shop
          NavigationDestination(
            icon: const Icon(Icons.shopping_bag_outlined),  // ✅ Better icon
            selectedIcon: const Icon(Icons.shopping_bag),
            label: context.tr('nav_shop'),
          ),
          
          // Sports
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: const Icon(Icons.sports_soccer),
            label: context.tr('nav_sports'),
          ),
          
          // ✅ REMOVED: Games navigation
          // ✅ REMOVED: Profile navigation (moved to hamburger)
          
          // ✅ ADDED: Hamburger Menu (More)
          NavigationDestination(
            icon: const Icon(Icons.menu),
            selectedIcon: const Icon(Icons.menu_open),
            label: context.tr('more'),  // "More" or "Mai mult"
          ),
        ],
      ),
    );
  }
}

/// Wrapper pentru ProductsListScreen
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductsListScreen();
  }
}

// ✅ REMOVED: ProfileScreenTab (acum în hamburger menu)