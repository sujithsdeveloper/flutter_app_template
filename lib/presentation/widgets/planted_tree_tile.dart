import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/presentation/pages/worker/worker_tree_detail_screen.dart';

class PlantedTreeTile extends StatelessWidget {
  const PlantedTreeTile({super.key, required this.tree, required this.t});

  final TreeModel tree;
  final AppText t;

  Future<void> _openTree(BuildContext context) async {
    final session = await getIt<SessionManager>().getSession();
    if (!context.mounted || session == null) return;
    final planterId = tree.plantedById ?? tree.workerId;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerTreeDetailScreen(
          tree: tree,
          workerId: session.userId,
          readOnly: planterId != session.userId,
          syncGrowth: tree.serverId != null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantingDate = tree.plantingDate;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(tree.species ?? '—'),
        subtitle: Text(
          [
            '${t.plantedBy}: ${tree.plantedBy ?? t.unknownPlanter}',
            if (plantingDate != null)
              '${t.plantedOn}: ${DateFormat.yMMMd().format(plantingDate)}',
          ].join('\n'),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openTree(context),
      ),
    );
  }
}
