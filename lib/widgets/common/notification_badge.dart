import 'package:flutter/material.dart';

/// Badge pentru notificări - afișează COUNTER în loc de bulină roșie
/// ✅ UPGRADE: Acum arată numărul de notificări (ex: 3, 12, 99+)
/// Dacă count == 0 → nu arată nimic
/// Dacă count == 1-99 → arată numărul
/// Dacă count > 99 → arată "99+"
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  
  /// Backward compatibility: dacă folosești showBadge=true, arată doar dot
  final bool? showBadge;

  const NotificationBadge({
    super.key,
    required this.child,
    this.count = 0,
    this.showBadge,
  });

  @override
  Widget build(BuildContext context) {
    // Determinăm dacă arătăm badge-ul
    final shouldShow = showBadge ?? (count > 0);
    
    if (!shouldShow) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: count > 0
              ? _buildCountBadge(context)
              : _buildDotBadge(context),
        ),
      ],
    );
  }

  /// Badge cu counter (număr)
  Widget _buildCountBadge(BuildContext context) {
    final displayText = count > 99 ? '99+' : count.toString();
    
    // Calculăm width-ul bazat pe numărul de caractere
    final minWidth = displayText.length == 1 ? 18.0 : 
                     displayText.length == 2 ? 22.0 : 28.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Badge simplu (bulină roșie) - fallback
  Widget _buildDotBadge(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
    );
  }
}