import 'package:flutter/foundation.dart';
import 'notifications_api.g.dart';

class LoggedEvent {
  LoggedEvent(this.event, this.at);
  final NotificationEvent event;
  final DateTime at;

  String get text {
    final t = at.toIso8601String().substring(11, 19);
    final action = event.actionId == null ? '' : ' (${event.actionId})';
    return '$t  ${event.type.name}  #${event.notificationId}$action';
  }
}

/// The generated NotificationsFlutterApi is what native calls into.
class NotificationCenter extends ChangeNotifier implements NotificationsFlutterApi {
  NotificationCenter._();
  static final instance = NotificationCenter._();

  final events = <LoggedEvent>[];

  @override
  void onEvent(NotificationEvent event) {
    events.insert(0, LoggedEvent(event, DateTime.now()));
    notifyListeners();
  }

  Future<void> start() async {
    NotificationsFlutterApi.setUp(this); // listen first
    await NotificationsHostApi().startListening(); // then tell native, which flushes its buffer
  }
}