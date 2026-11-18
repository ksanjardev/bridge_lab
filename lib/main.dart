import 'package:flutter/material.dart';
import 'app/app.dart';
import 'features/notifications/notification_center.dart';
import 'features/share_inbox/share_inbox.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ShareInbox.instance.start();
  NotificationCenter.instance.start();
  runApp(const BridgeLabApp());
}