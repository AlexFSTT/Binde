import 'package:flutter/material.dart';
import '../../models/swirl_model.dart';
import '../../services/swirls_service.dart';
import 'swirl_player_screen.dart';

/// Feed-ul principal pentru Swirls - scroll vertical TikTok-style
class SwirlsFeedScreen extends StatefulWidget {
  const SwirlsFeedScreen({super.key});

  @override
  State<SwirlsFeedScreen> createState() => _SwirlsFeedScreenState();
}

class _SwirlsFeedScreenState extends State<SwirlsFeedScreen> {
  final SwirlsService _swirlsService = SwirlsService();
  List<Swirl> _swirls = [];
  bool _isLoading = true;
  String? _error;
  
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSwirls();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSwirls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final swirls = await _swirlsService.getSwirls();
      setState(() {
        _swirls = swirls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Error loading swirls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSwirls,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_swirls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 80,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            const Text(
              'No swirls available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back later for new content!',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    // TikTok-style vertical scroll PageView
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _swirls.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final swirl = _swirls[index];
        return SwirlPlayerScreen(
          swirl: swirl,
          isActive: index == _currentIndex,
        );
      },
    );
  }
}
