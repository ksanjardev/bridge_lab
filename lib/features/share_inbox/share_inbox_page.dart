import 'dart:io';

import 'package:flutter/material.dart';

import 'share_inbox.dart';
import 'shared_item.dart';

class ShareInboxPage extends StatefulWidget {
  const ShareInboxPage({super.key});

  @override
  State<ShareInboxPage> createState() => _ShareInboxPageState();
}

class _ShareInboxPageState extends State<ShareInboxPage> {
  @override
  void initState() {
    super.initState();
    ShareInbox.instance.pageOpen = true;
  }

  @override
  void dispose() {
    ShareInbox.instance.pageOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Inbox')),
      body: ListenableBuilder(
        listenable: ShareInbox.instance,
        builder: (context, _) {
          final items = ShareInbox.instance.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing yet.\nIn another app, tap Share and choose Bridge Lab.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ItemTile(items[i]),
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile(this.item);

  final SharedItem item;

  @override
  Widget build(BuildContext context) {
    final t = item.receivedAt.toIso8601String().substring(11, 19);
    switch (item.kind) {
      case SharedKind.text:
        return ListTile(
          leading: const Icon(Icons.notes),
          title: Text(item.text ?? ''),
          subtitle: Text('${item.subject == null ? '' : '${item.subject} · '}$t'),
        );
      case SharedKind.image:
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(item.path!),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              cacheWidth: 200,
              // decode small, don't load a 12 MP photo for a thumbnail
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
            ),
          ),
          title: Text(item.name ?? 'image'),
          subtitle: Text('${_size(item.sizeBytes)} · $t'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(child: Image.file(File(item.path!))),
          ),
        );
      case SharedKind.file:
        return ListTile(
          leading: const Icon(Icons.insert_drive_file),
          title: Text(item.name ?? 'file'),
          subtitle: Text('${item.mimeType} · ${_size(item.sizeBytes)} · $t'),
        );
    }
  }

  static String _size(int? bytes) {
    if (bytes == null) return '?';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
