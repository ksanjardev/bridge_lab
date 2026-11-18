import 'package:flutter/foundation.dart';
import 'share_service.dart';
import 'shared_item.dart';

/// App-wide store. It listens from startup, not from page open.
class ShareInbox extends ChangeNotifier {
  ShareInbox._();
  static final instance = ShareInbox._();

  final _service = ShareService();
  final items = <SharedItem>[];
  bool pageOpen = false;
  void Function()? onShare; // set by the app to navigate

  Future<void> start() => _service.start((item) {
    items.insert(0, item);
    notifyListeners();
    onShare?.call();
  });
}