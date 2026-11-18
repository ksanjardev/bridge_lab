import 'package:flutter/material.dart';

import 'race_service.dart';

class ComparePage extends StatelessWidget {
  const ComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compare'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Which one?'),
              Tab(text: 'Speed race'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_GuideTab(), _RaceTab()],
        ),
      ),
    );
  }
}


/// Tab 1: the decision guide. Plain data, so it is easy to read and to edit.
class _Option {
  const _Option(this.icon, this.name, this.useWhen, this.watchOut, this.demo);
  final IconData icon;
  final String name;
  final String useWhen;
  final String watchOut;
  final String demo;
}

const _options = [
  _Option(
    Icons.call_made,
    'MethodChannel',
    'You need a one-off request and answer: "do this, tell me the result". '
        'Scheduling a job, opening a screen, reading a setting.',
    'Method names and arguments are untyped strings and maps. A typo only '
        'fails at runtime.',
    'Background Sync (WorkManager)',
  ),
  _Option(
    Icons.waves,
    'EventChannel',
    'The platform keeps producing values over time and Dart listens: '
        'battery, connectivity, sensors, location.',
    'One listener per channel. Events must be sent from the main thread. '
        'Always clean up in onCancel.',
    'Live Status (battery and network)',
  ),
  _Option(
    Icons.swap_horiz,
    'BasicMessageChannel',
    'Messages flow both ways with your own protocol, not method calls. '
        'Also the transport Pigeon is built on.',
    'No method names, no types: you design the message format yourself. '
        'No listener on the other side means a null reply.',
    'Share Inbox (receive shared photos and files)',
  ),
  _Option(
    Icons.verified_outlined,
    'Pigeon',
    'You have many calls or both directions, and a team that should not '
        'break the contract by accident. You write the API once, both sides are generated.',
    'An extra generator step. Generated code changes shape between versions.',
    'Notifications (actions and events)',
  ),
  _Option(
    Icons.memory,
    'dart:ffi + FFIgen',
    'You have C or C++ code, or heavy computation on big buffers where '
        'copying messages would be slow: images, audio, crypto.',
    'You manage native memory yourself. Calls block the isolate they run on. '
        'Errors are return codes.',
    'Photo Filters (C image code)',
  ),
  _Option(
    Icons.android,
    'JNI + JNIgen',
    'You want to call Android SDK classes straight from Dart without writing '
        'Kotlin: quick synchronous reads and small features.',
    'Android only. Your Dart code now contains Android API knowledge. '
        'Some calls need the Android main thread, which Dart does not run on.',
    'Device Inspector',
  ),
];

class _GuideTab extends StatelessWidget {
  const _GuideTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            'Six ways to reach Android from Flutter. Each card says when it is '
                'the right tool, what to watch out for, and which page in this app '
                'demonstrates it.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        for (final o in _options)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(o.icon, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(o.name, style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _line(theme, 'Use it when', o.useWhen),
                  const SizedBox(height: 8),
                  _line(theme, 'Watch out', o.watchOut),
                  const SizedBox(height: 8),
                  _line(theme, 'See it in', o.demo),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _line(ThemeData theme, String label, String text) {
    return Text.rich(TextSpan(children: [
      TextSpan(
        text: '$label: ',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      TextSpan(text: text),
    ]));
  }
}

/// Tab 2: the race.
class _RaceTab extends StatefulWidget {
  const _RaceTab();

  @override
  State<_RaceTab> createState() => _RaceTabState();
}

class _RaceTabState extends State<_RaceTab> {
  final _service = RaceService();
  List<RaceResult>? _results;
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    // Let the spinner paint before the synchronous contestants block the UI.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final results = await _service.run();
    if (!mounted) return;
    setState(() {
      _results = results;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    final slowest = results == null
        ? 1.0
        : results
        .map((r) => r.microsPerCall ?? 0)
        .fold<double>(1, (a, b) => b > a ? b : a);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Each contestant makes the same trivial call ${RaceService.calls} times. '
                'The work behind the call is almost nothing, so the numbers show the '
                'price of the bridge itself. Shorter bar = cheaper call.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.flag),
            label: Text(_running ? 'Racing…' : 'Start the race'),
          ),
          const SizedBox(height: 16),
          if (results != null)
            Expanded(
              child: ListView(
                children: [
                  for (final r in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(r.label,
                                    style: theme.textTheme.titleSmall),
                              ),
                              Text(
                                r.microsPerCall == null
                                    ? 'n/a'
                                    : '${r.microsPerCall!.toStringAsFixed(1)} µs / call',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: r.microsPerCall == null
                                ? 0
                                : (r.microsPerCall! / slowest).clamp(0.01, 1.0),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          Text(r.note, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  Text(
                    'Tip: run this in a profile build (flutter run --profile). '
                        'Debug builds make Dart slower and blur the differences.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}