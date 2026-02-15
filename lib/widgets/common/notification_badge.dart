import 'package:flutter/material.dart';

/// Badge roșu pentru notificări necitite
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final bool showBadge;
  final double size;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.showBadge,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showBadge)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
