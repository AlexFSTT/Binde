import 'package:flutter/material.dart';
import '../../screens/updates/updates_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/tools/tools_screen.dart';
import '../../l10n/app_localizations.dart';

/// Shows the menu bubble overlay with jelly animation
void showMenuBubble(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return MenuBubbleOverlay(animation: animation);
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    ),
  );
}

class MenuBubbleOverlay extends StatefulWidget {
  final Animation<double> animation;

  const MenuBubbleOverlay({super.key, required this.animation});

  @override
  State<MenuBubbleOverlay> createState() => _MenuBubbleOverlayState();
}

class _MenuBubbleOverlayState extends State<MenuBubbleOverlay>
    with TickerProviderStateMixin {
  late AnimationController _jellyController;
  late AnimationController _staggerController;
  late Animation<double> _jellyX;
  late Animation<double> _jellyY;

  @override
  void initState() {
    super.initState();

    // Jelly wobble controller
    _jellyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _jellyX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 0.98), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.01), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.01, end: 0.995), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.995, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _jellyController,
      curve: Curves.easeOut,
    ));

    _jellyY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.97), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.02), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 0.99), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.99, end: 1.005), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.005, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _jellyController,
      curve: Curves.easeOut,
    ));

    // Stagger animation for menu items
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Start jelly after the bubble appears
    widget.animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _jellyController.forward();
        _staggerController.forward();
      }
    });

    // If already completed (e.g., hot reload)
    if (widget.animation.isCompleted) {
      _jellyController.forward();
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    _jellyController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.pop(context); // Close bubble
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final bubbleWidth = screenWidth * 0.75;
    final bubbleRight = 12.0;
    final bubbleBottom = bottomPadding + 72.0; // Above nav bar

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) => Container(
                color: Colors.black
                    .withValues(alpha: 0.35 * widget.animation.value),
              ),
            ),
          ),

          // Bubble
          Positioned(
            right: bubbleRight,
            bottom: bubbleBottom,
            child: AnimatedBuilder(
              animation: Listenable.merge([widget.animation, _jellyController]),
              builder: (context, child) {
                final curved = CurvedAnimation(
                  parent: widget.animation,
                  curve: Curves.easeOutBack,
                );

                final scaleX =
                    curved.value * (_jellyController.isAnimating ? _jellyX.value : 1.0);
                final scaleY =
                    curved.value * (_jellyController.isAnimating ? _jellyY.value : 1.0);

                return Transform(
                  alignment: Alignment.bottomRight,
                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                  child: Opacity(
                    opacity: widget.animation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: bubbleWidth,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.06),
                      blurRadius: 40,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(colorScheme),
                      _buildMenuItems(colorScheme),
                      _buildFooter(colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Small triangle pointer at bottom-right
          Positioned(
            right: bubbleRight + 20,
            bottom: bubbleBottom - 7,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) => Opacity(
                opacity: widget.animation.value.clamp(0.0, 1.0),
                child: child,
              ),
              child: CustomPaint(
                size: const Size(16, 8),
                painter: _BubbleArrowDownPainter(color: colorScheme.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Animated logo
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Transform.rotate(
                angle: (1 - value) * 0.5,
                child: child,
              ),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.rocket_launch_rounded,
                  color: colorScheme.onPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Binde',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 1),
                Text('v0.5.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    )),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                size: 22),
            style: IconButton.styleFrom(
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(ColorScheme colorScheme) {
    final items = [
      _MenuItem(
        icon: Icons.notifications_active_rounded,
        title: context.tr('updates'),
        color: Colors.amber[700]!,
        onTap: () => _navigateTo(const UpdatesScreen()),
      ),
      _MenuItem(
        icon: Icons.person_rounded,
        title: context.tr('profile'),
        color: colorScheme.primary,
        onTap: () => _navigateTo(const ProfileScreen()),
      ),
      _MenuItem(
        icon: Icons.construction_rounded,
        title: context.tr('tools'),
        color: Colors.teal,
        badge: context.tr('coming_soon'),
        onTap: () => _navigateTo(const ToolsScreen()),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          final delay = (index * 0.12).clamp(0.0, 0.5);
          final end = (delay + 0.5).clamp(0.0, 1.0);

          return AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              final progress =
                  Interval(delay, end, curve: Curves.easeOutCubic)
                      .transform(_staggerController.value);
              return Transform.translate(
                offset: Offset(0, 15 * (1 - progress)),
                child: Opacity(
                  opacity: progress.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: _buildMenuTile(items[index], colorScheme),
          );
        }),
      ),
    );
  }

  Widget _buildMenuTile(_MenuItem item, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: item.color.withValues(alpha: 0.08),
          highlightColor: item.color.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 14),

                // Title
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),

                // Badge or arrow
                if (item.badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.badge!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: item.color,
                      ),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _showAboutDialog(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                context.tr('about_app'),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.rocket_launch, size: 48, color: colorScheme.primary),
        title: Text(context.tr('about_binde')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('binde_tagline'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Text('${context.tr('version')}: v0.5.0',
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            Text(context.tr('binde_description'),
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4)),
            const SizedBox(height: 16),
            Text('© 2026 Binde. All rights reserved.',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.color,
    this.badge,
    required this.onTap,
  });
}

/// Triangle arrow pointing down (chat bubble tail toward nav bar)
class _BubbleArrowDownPainter extends CustomPainter {
  final Color color;
  _BubbleArrowDownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}