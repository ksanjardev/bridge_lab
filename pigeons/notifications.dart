import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/features/notifications/notifications_api.g.dart',
  kotlinOut:
  'android/app/src/main/kotlin/com/example/bridge_lab/bridges/NotificationsApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.bridge_lab.bridges'),
))
enum Importance { low, normal, high }

enum NotificationEventType { tapped, actionPressed, dismissed }

class NotificationAction {
  NotificationAction({required this.id, required this.label});
  String id;
  String label;
}

class NotificationRequest {
  NotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.importance,
    required this.actions,
  });
  int id;
  String title;
  String body;
  Importance importance;
  List<NotificationAction> actions;
}

class ActiveNotification {
  ActiveNotification({required this.id, required this.title, required this.body});
  int id;
  String title;
  String body;
}

class NotificationEvent {
  NotificationEvent({required this.notificationId, required this.type, this.actionId});
  int notificationId;
  NotificationEventType type;
  String? actionId;
}

/// Dart calls native.
@HostApi()
abstract class NotificationsHostApi {
  bool hasPermission();

  @async
  bool requestPermission();

  void show(NotificationRequest request);

  void cancel(int id);

  List<ActiveNotification> activeNotifications();

  /// Dart is ready to receive events (replaces the hand-made "ready" message from Phase 3).
  void startListening();
}

/// Native calls Dart.
@FlutterApi()
abstract class NotificationsFlutterApi {
  void onEvent(NotificationEvent event);
}