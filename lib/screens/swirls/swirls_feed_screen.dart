import 'package:flutter/material.dart';
import '../../models/swirl_model.dart';
import '../../services/swirls_service.dart';
import 'swirl_player_screen.dart';
import 'swirl_upload_screen.dart';

/// Feed-ul principal pentru Swirls - scroll vertical TikTok-style
/// Cu detectare corectă când tabul devine vizibil/invizibil
class SwirlsFeedScreen extends StatefulWidget {
  const SwirlsFeedScreen({super.key});

  @override
  State<SwirlsFeedScreen> createState() => SwirlsFeedScreenState();
}

class SwirlsFeedScreenState extends State<SwirlsFeedScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  
  final SwirlsService _swirlsService = SwirlsService();
  List<Swirl> _swirls = [];
  bool _isLoading = true;
  String? _error;
  
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  
  // ✅ Flag pentru vizibilitate - INIȚIAL FALSE!
  bool _isVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSwirls();
    
    // ✅ Așteaptă puțin înainte de a permite video să pornească
    // Acest delay asigură că nu pornește imediat la deschiderea app-ului
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Video va porni doar dacă userul E PE TABUL ACESTA
        // Nu pornim automat - așteptăm ca userul să navigheze activ aici
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App în background → stop video
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // App în foreground → doar dacă eram deja vizibili
      if (mounted && _isVisible) {
        setState(() {}); // Trigger rebuild
      }
    }
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

  // ✅ METODE PUBLICE pentru Home Screen să le apeleze
  // Home screen va apela aceste metode când tabul devine vizibil/invizibil
  
  void onTabVisible() {
    if (mounted) {
      setState(() {
        _isVisible = true;
      });
    }
  }
  
  void onTabHidden() {
    if (mounted) {
      setState(() {
        _isVisible = false;
      });
    }
  }

  Future<void> _openUploadScreen() async {
    // Pause video când deschizi upload
    setState(() {
      _isVisible = false;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SwirlUploadScreen(),
      ),
    );

    // Resume dacă eram vizibili înainte
    setState(() {
      _isVisible = true;
    });

    if (result == true) {
      _loadSwirls();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(colorScheme),
      floatingActionButton: FloatingActionButton(
        onPressed: _openUploadScreen,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        tooltip: 'Upload Swirl',
        child: const Icon(Icons.add),
      ),
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openUploadScreen,
              icon: const Icon(Icons.upload),
              label: const Text('Upload Your First Swirl'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
        
        // ✅ Video activ DOAR dacă:
        // 1. E video-ul curent ÎN PageView
        // 2. Tabul e vizibil (_isVisible = true)
        final isActive = index == _currentIndex && _isVisible;
        
        return SwirlsPlayerScreen(
          swirl: swirl,
          isActive: isActive,
        );
      },
    );
  }
}
