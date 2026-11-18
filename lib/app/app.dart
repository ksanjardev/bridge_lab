import 'package:flutter/material.dart';
import '../features/catalog/catalog_page.dart';
import '../features/share_inbox/share_inbox.dart';
import '../features/share_inbox/share_inbox_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class BridgeLabApp extends StatefulWidget {
  const BridgeLabApp({super.key});

  @override
  State<BridgeLabApp> createState() => _BridgeLabAppState();
}

class _BridgeLabAppState extends State<BridgeLabApp> {
  @override
  void initState() {
    super.initState();
    ShareInbox.instance.onShare = () {
      // Wait for a frame so the navigator exists on a cold start.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ShareInbox.instance.pageOpen) return;
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ShareInboxPage()),
        );
      });
    };
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    title: 'Bridge Lab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const CatalogPage(),
  );
}