import 'package:flutter/services.dart';

import 'shared_item.dart';

class ShareService {
  static const _channel = BasicMessageChannel<Object?>('bridge_lab/share', JSONMessageCodec());

  /// Start listening, then tell native we're ready.
  /// The order matters: handler first, "ready" second.
  Future<void> start(void Function(SharedItem) onItem) async {
    // Native -> Dart: a live share. Whatever we return is the reply.
    _channel.setMessageHandler((message) async {
      onItem(SharedItem.fromJson(Map<String, Object?>.from(message as Map)));
      return {'status': 'saved'};
    });

    // Dart -> native: the handshake. The reply carries shares that arrived early.
    final reply = await _channel.send({'type': 'ready'});
    final pending = (Map<String, Object?>.from(reply as Map))['pending'] as List<Object?>;
    for (final p in pending) {
      onItem(SharedItem.fromJson(Map<String, Object?>.from(p as Map)));
    }
  }

  void stop() => _channel.setMessageHandler(null);
}
