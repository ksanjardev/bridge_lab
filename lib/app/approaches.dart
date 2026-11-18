import 'package:bridge_lab/features/live_status/live_status_page.dart';
import 'package:bridge_lab/features/notifications/notification_page.dart';
import 'package:bridge_lab/features/share_inbox/share_inbox_page.dart';
import 'package:flutter/material.dart';
import '../core/approach.dart';
import '../features/catalog/coming_soon_page.dart';
import '../features/background_sync/background_sync_page.dart';
import '../features/device_inspector/device_inspector_page.dart';
import '../features/image_lab/image_lab_page.dart';

final approaches = <Approach>[
  Approach(
    title: 'MethodChannel',
    useCase: 'Schedule background sync with WorkManager',
    icon: Icons.sync,
    pageBuilder: (_) => const BackgroundSyncPage(),
  ),
  Approach(
    title: 'EventChannel',
    useCase: 'Live battery & connectivity from BroadcastReceiver',
    icon: Icons.sensors,
    pageBuilder: (_) => const LiveStatusPage(),
  ),
  Approach(
    title: 'BasicMessageChannel',
    useCase: 'Receive text shared from other apps',
    icon: Icons.inbox,
    pageBuilder: (_) => const ShareInboxPage(),
  ),
  Approach(
    title: 'Pigeon',
    useCase: 'Typed notifications API, both directions',
    icon: Icons.notifications,
    pageBuilder: (_) => const NotificationsPage(),
  ),
  Approach(
    title: 'dart:ffi + FFIgen',
    useCase: 'Native C image processing',
    icon: Icons.memory,
    pageBuilder: (_) => const ImageLabPage(),
  ),
  Approach(
    title: 'JNI + JNIgen',
    useCase: 'Call Android SDK directly from Dart',
    icon: Icons.android,
    pageBuilder: (_) => const DeviceInspectorPage(),
  ),
];