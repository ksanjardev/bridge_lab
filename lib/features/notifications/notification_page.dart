import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notification_center.dart';
import 'notifications_api.g.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _host = NotificationsHostApi();
  final _title = TextEditingController(text: 'Build finished');
  final _body = TextEditingController(text: 'Tap me, or press an action.');
  Importance _importance = Importance.normal;
  bool _withActions = true;
  int _nextId = 1;
  List<ActiveNotification> _active = [];

  @override
  void initState() {
    super.initState();
    NotificationCenter.instance.addListener(_refresh); // an event usually changes the list
    _refresh();
  }

  @override
  void dispose() {
    NotificationCenter.instance.removeListener(_refresh);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await _host.activeNotifications();
    if (mounted) setState(() => _active = list);
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _show() async {
    try {
      final allowed = await _host.hasPermission() || await _host.requestPermission();
      if (!allowed) {
        _snack('Notifications are blocked for this app.');
        return;
      }
      await _host.show(NotificationRequest(
        id: _nextId++,
        title: _title.text,
        body: _body.text,
        importance: _importance,
        actions: _withActions
            ? [
          NotificationAction(id: 'done', label: 'Done'),
          NotificationAction(id: 'snooze', label: 'Snooze'),
        ]
            : [],
      ));
      await _refresh();
    } on PlatformException catch (e) {
      _snack('${e.code}: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: _body, decoration: const InputDecoration(labelText: 'Body')),
          const SizedBox(height: 12),
          SegmentedButton<Importance>(
            segments: [
              for (final i in Importance.values)
                ButtonSegment(value: i, label: Text(i.name)),
            ],
            selected: {_importance},
            onSelectionChanged: (v) => setState(() => _importance = v.first),
          ),
          SwitchListTile(
            title: const Text('Add "Done" and "Snooze" buttons'),
            value: _withActions,
            onChanged: (v) => setState(() => _withActions = v),
          ),
          FilledButton(onPressed: _show, child: const Text('Show notification')),
          const Divider(height: 32),
          Text('Active (${_active.length})', style: Theme.of(context).textTheme.titleMedium),
          for (final n in _active)
            ListTile(
              title: Text('#${n.id}  ${n.title}'),
              subtitle: Text(n.body),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await _host.cancel(n.id);
                  await _refresh();
                },
              ),
            ),
          const Divider(height: 32),
          Text('Events from native', style: Theme.of(context).textTheme.titleMedium),
          ListenableBuilder(
            listenable: NotificationCenter.instance,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in NotificationCenter.instance.events)
                  Text(e.text, style: const TextStyle(fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}