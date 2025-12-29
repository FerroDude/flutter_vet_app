import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';

/// A wrapper widget that listens to app lifecycle events and triggers
/// message delivery status updates when the app comes to foreground.
class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - mark messages as delivered
      _markMessagesAsDelivered();
    }
  }

  Future<void> _markMessagesAsDelivered() async {
    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.markAllMessagesAsDeliveredOnSync();
    } catch (e) {
      // ChatProvider might not be available in some contexts, ignore
      debugPrint('AppLifecycleWrapper: Could not mark messages as delivered: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

