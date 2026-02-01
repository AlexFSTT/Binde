import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/hamburger_menu.dart';
import '../chat/conversations_screen.dart';
import '../learn/lessons_list_screen.dart';
import '../swirls/swirls_feed_screen.dart';
import '../shop/products_list_screen.dart';
import '../sports/sports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // ✅ GlobalKey pentru Swirls feed
  final GlobalKey<SwirlsFeedScreenState> _swirlsFeedKey = GlobalKey<SwirlsFeedScreenState>();
  
  // GlobalKey pentru drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ✅ UPDATED: Folosim GlobalKey pentru SwirlsFeedScreen
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    // Inițializăm screens cu GlobalKey pentru Swirls
    _screens = [
      const ConversationsScreen(),     // 0 - Chat
      const LessonsListScreen(),       // 1 - Learn
      SwirlsFeedScreen(key: _swirlsFeedKey), // ✅ 2 - Swirls (cu GlobalKey!)
      const ShopScreen(),              // 3 - Shop
      const SportsScreen(),            // 4 - Sports
    ];
  }

  void _onNavigationTap(int index) {
    if (index == 5) {
      // Hamburger menu - deschide drawer
      _scaffoldKey.currentState?.openDrawer();
    } else {
      // ✅ DETECTARE SCHIMBARE TAB pentru Swirls
      final oldIndex = _currentIndex;
      const swirlsIndex = 2; // Swirls e pe index 2
      
      // Detectează când INTRI în Swirls
      if (index == swirlsIndex && oldIndex != swirlsIndex) {
        // INTRAT în Swirls → pornește video
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _swirlsFeedKey.currentState?.onTabVisible();
        });
      }
      
      // Detectează când IEȘI din Swirls
      if (oldIndex == swirlsIndex && index != swirlsIndex) {
        // IEȘIT din Swirls → oprește video
        _swirlsFeedKey.currentState?.onTabHidden();
      }
      
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      
      drawer: const HamburgerMenu(),
      
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigationTap,
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
          
          // Swirls
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: context.tr('nav_swirls'),
          ),
          
          // Shop
          NavigationDestination(
            icon: const Icon(Icons.shopping_bag_outlined),
            selectedIcon: const Icon(Icons.shopping_bag),
            label: context.tr('nav_shop'),
          ),
          
          // Sports
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: const Icon(Icons.sports_soccer),
            label: context.tr('nav_sports'),
          ),
          
          // Hamburger Menu (More)
          NavigationDestination(
            icon: const Icon(Icons.menu),
            selectedIcon: const Icon(Icons.menu_open),
            label: context.tr('more'),
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