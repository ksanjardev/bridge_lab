import 'package:bridge_lab/features/compare/compare_page.dart';
import 'package:flutter/material.dart';
import '../../app/approaches.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bridge Lab'),
      actions: [
        IconButton(
          icon: const Icon(Icons.compare_arrows),
          tooltip: 'Compare the approaches',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ComparePage()),
          ),
        ),
      ],),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: approaches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = approaches[i];
        return Card(
          child: ListTile(
            leading: Icon(a.icon),
            title: Text('${i + 1}. ${a.title}'),
            subtitle: Text(a.useCase),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: a.pageBuilder)),
          ),
        );
      },
    ),
  );
}