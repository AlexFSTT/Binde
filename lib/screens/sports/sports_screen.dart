import 'package:flutter/material.dart';
import 'sports_news_tab.dart';
import 'sports_live_tab.dart';

class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> with SingleTickerProviderStateMixin {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.newspaper),
              text: 'News',
            ),
            Tab(
              icon: Icon(Icons.live_tv),
              text: 'Live',
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