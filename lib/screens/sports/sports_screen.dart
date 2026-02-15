import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/notification_badge.dart';
import '../../providers/notification_provider.dart';
import '../notifications/notifications_screen.dart';
import 'sports_news_tab.dart';
import 'sports_live_tab.dart';

class SportsScreen extends ConsumerStatefulWidget {
  const SportsScreen({super.key});

  @override
  ConsumerState<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends ConsumerState<SportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // ✅ Badge doar pentru SPORTS notifications
    final hasSportsNotifications = ref.watch(hasSportsUnreadNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav_sports')),
        actions: [
          // Notification bell - doar sports updates
          IconButton(
            icon: NotificationBadge(
              showBadge: hasSportsNotifications,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(category: 'sports'),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.newspaper),
              text: context.tr('news'),
            ),
            Tab(
              icon: const Icon(Icons.live_tv),
              text: context.tr('live'),
            ),
          ],
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SportsNewsTab(),
          SportsLiveTab(),
        ],
      ),
    );
  }
}