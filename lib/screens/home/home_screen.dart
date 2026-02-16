import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/hamburger_menu.dart';
import '../../widgets/common/notification_badge.dart';
import '../../providers/notification_provider.dart';
import '../chat/conversations_screen.dart';
import '../learn/lessons_list_screen.dart';
import '../shop/products_list_screen.dart';
import '../sports/sports_screen.dart';

/// Home screen cu bottom navigation
/// ✅ REALTIME: Badge-urile pe tab-uri se actualizează automat
/// ✅ UPGRADE: Counter badges (3, 12, 99+) în loc de bulină roșie
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    _screens = [
      const ConversationsScreen(),     // 0 - Chat
      const LessonsListScreen(),       // 1 - Learn
      const ShopScreen(),              // 2 - Shop
      const SportsScreen(),            // 3 - Sports
    ];
  }

  void _onNavigationTap(int index) {
    if (index == 4) {
      // Hamburger menu
      _scaffoldKey.currentState?.openDrawer();
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ COUNT pentru Chat: friend requests + mesaje necitite
    final chatBadgeCount = ref.watch(chatBadgeCountProvider);
    
    // ✅ COUNT pentru Learn
    final learnBadgeCount = ref.watch(learnBadgeCountProvider);

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
          // ✅ Chat - COUNTER badge (friend requests + mesaje necitite)
          NavigationDestination(
            icon: NotificationBadge(
              count: chatBadgeCount,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: NotificationBadge(
              count: chatBadgeCount,
              child: const Icon(Icons.chat_bubble),
            ),
            label: context.tr('nav_chat'),
          ),
          
          // ✅ Learn - COUNTER badge
          NavigationDestination(
            icon: NotificationBadge(
              count: learnBadgeCount,
              child: const Icon(Icons.school_outlined),
            ),
            selectedIcon: NotificationBadge(
              count: learnBadgeCount,
              child: const Icon(Icons.school),
            ),
            label: context.tr('nav_learn'),
          ),
          
          // Shop - fără badge
          NavigationDestination(
            icon: const Icon(Icons.shopping_bag_outlined),
            selectedIcon: const Icon(Icons.shopping_bag),
            label: context.tr('nav_shop'),
          ),
          
          // Sports - badge în screen-ul propriu
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: const Icon(Icons.sports_soccer),
            label: context.tr('nav_sports'),
          ),
          
          // Hamburger Menu
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