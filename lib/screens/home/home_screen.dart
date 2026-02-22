import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/hamburger_menu.dart';
import '../../widgets/common/notification_badge.dart';
import '../../providers/notification_provider.dart';
import '../chat/conversations_screen.dart';
import '../shop/products_list_screen.dart';

/// Home screen cu bottom navigation
/// ✅ CLEANUP: Eliminat Learn și Sports
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
      const ShopScreen(),              // 1 - Shop
    ];
  }

  void _onNavigationTap(int index) {
    if (index == 2) {
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
    final chatBadgeCount = ref.watch(chatBadgeCountProvider);

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
          
          NavigationDestination(
            icon: const Icon(Icons.shopping_bag_outlined),
            selectedIcon: const Icon(Icons.shopping_bag),
            label: context.tr('nav_shop'),
          ),
          
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