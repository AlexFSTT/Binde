import 'package:flutter/material.dart';
import '../services/presence_service.dart';

/// Manager pentru lifecycle-ul aplicației
/// Gestionează status-ul ONLINE/OFFLINE la nivel de aplicație
/// Se setează ONLINE când aplicația pornește
/// Se setează OFFLINE când aplicația se închide sau merge în background
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({
    super.key,
    required this.child,
  });

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  final PresenceService _presenceService = PresenceService();

  @override
  void initState() {
    super.initState();
    
    // Adăugăm observer pentru lifecycle
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ SETĂM UTILIZATORUL CA ONLINE CÂND PORNEȘTE APLICAȚIA
    debugPrint('🚀 App started - setting user ONLINE');
    _presenceService.setOnline();
  }

  @override
  void dispose() {
    // ✅ SETĂM UTILIZATORUL CA OFFLINE CÂND SE ÎNCHIDE APLICAȚIA
    debugPrint('🛑 App closing - setting user OFFLINE');
    _presenceService.setOffline();
    
    // Eliminăm observer-ul
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Detectează când aplicația merge în background/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('📱 App lifecycle changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Aplicația revine în foreground → ONLINE
        debugPrint('✅ App resumed - setting user ONLINE');
        _presenceService.setOnline();
        break;
        
      case AppLifecycleState.paused:
        // Aplicația merge în background → OFFLINE
        debugPrint('⏸️ App paused - setting user OFFLINE');
        _presenceService.setOffline();
        break;
        
      case AppLifecycleState.inactive:
        // Aplicația devine inactivă (ex: primește apel)
        debugPrint('⚠️ App inactive');
        // Nu setăm offline aici pentru că poate reveni instant
        break;
        
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Aplicația se închide complet → OFFLINE
        debugPrint('🔴 App detached/hidden - setting user OFFLINE');
        _presenceService.setOffline();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Returnăm child-ul fără modificări
    // Acest widget e transparent pentru UI
    return widget.child;
  }
}
