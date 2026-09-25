import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/tree_growth_update_model.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/repositories/tree_growth_repository.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/presentation/pages/worker/worker_tree_detail_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

/// Displays all trees planted by this field volunteer — styled like admin tabs.
class WorkerTreesScreen extends StatefulWidget {
  const WorkerTreesScreen({super.key, required this.session});
  final UserSession session;

  @override
  State<WorkerTreesScreen> createState() => _WorkerTreesScreenState();
}

class _WorkerTreesScreenState extends State<WorkerTreesScreen> {
  List<TreeModel> _trees = [];
  Map<String, GrowthStage> _stages = {};
  bool _loading = true;

  final _treeRepo = getIt<TreeRepository>();
  final _growthRepo = getIt<TreeGrowthRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final trees = await _treeRepo.getByWorkerId(widget.session.userId);
    final stages = await _growthRepo.getLatestStagesForWorker(
      widget.session.userId,
    );
    if (mounted) {
      setState(() {
        _trees = trees;
        _stages = stages;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, lang, _) {
        final t = AppText(lang);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TreesAppBar(
                  t: t,
                  count: _loading ? null : _trees.length,
                  onRefresh: _load,
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ColorConstants.forestGreen,
                            ),
                          ),
                        )
                      : _trees.isEmpty
                          ? _EmptyTrees(t: t)
                          : RefreshIndicator(
                              color: ColorConstants.forestGreen,
                              backgroundColor: ColorConstants.cardSurface,
                              onRefresh: _load,
                              child: ListView(
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  omEarthBottomScrollPadding(context),
                                ),
                                children: [
                                  _SummaryChips(
                                    t: t,
                                    trees: _trees,
                                    stages: _stages,
                                  ),
                                  const SizedBox(height: 14),
                                  for (int i = 0; i < _trees.length; i++) ...[
                                    _TreeCard(
                                      tree: _trees[i],
                                      stage: _stages[_trees[i].id] ??
                                          GrowthStage.planted,
                                      t: t,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              WorkerTreeDetailScreen(
                                            tree: _trees[i],
                                            workerId: widget.session.userId,
                                          ),
                                        ),
                                      ).then((_) => _load()),
                                    ),
                                    if (i < _trees.length - 1)
                                      const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _TreesAppBar extends StatelessWidget {
  const _TreesAppBar({
    required this.t,
    this.count,
    required this.onRefresh,
  });

  final AppText t;
  final int? count;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Image.asset(
            ImageConstants.leafSprig,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Text(
            t.myTrees,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ColorConstants.lightTextPrimary,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ColorConstants.softGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.forestGreen,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: ColorConstants.forestGreen,
            ),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyTrees extends StatelessWidget {
  const _EmptyTrees({required this.t});

  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              ImageConstants.matureTree,
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              t.noTreesPlanted,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorConstants.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.noTreesDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: ColorConstants.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary chips ─────────────────────────────────────────────────────────────

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.t,
    required this.trees,
    required this.stages,
  });

  final AppText t;
  final List<TreeModel> trees;
  final Map<String, GrowthStage> stages;

  @override
  Widget build(BuildContext context) {
    final counts = <GrowthStage, int>{};
    for (final tree in trees) {
      final s = stages[tree.id] ?? GrowthStage.planted;
      counts[s] = (counts[s] ?? 0) + 1;
    }

    final chips = <({String label, int count, Color color})>[];
    if ((counts[GrowthStage.growing] ?? 0) > 0) {
      chips.add((
        label: t.stageGrowing,
        count: counts[GrowthStage.growing]!,
        color: ColorConstants.forestGreen,
      ));
    }
    if ((counts[GrowthStage.established] ?? 0) > 0) {
      chips.add((
        label: t.stageEstablished,
        count: counts[GrowthStage.established]!,
        color: const Color(0xFF2E7D32),
      ));
    }
    if ((counts[GrowthStage.needsAttention] ?? 0) > 0) {
      chips.add((
        label: t.stageNeedsAttention,
        count: counts[GrowthStage.needsAttention]!,
        color: ColorConstants.warningColor,
      ));
    }
    if ((counts[GrowthStage.dead] ?? 0) > 0) {
      chips.add((
        label: t.stageDead,
        count: counts[GrowthStage.dead]!,
        color: ColorConstants.errorColor,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          OmEarthStatusChip(
            label: '${chip.count} ${chip.label}',
            color: chip.color,
          ),
      ],
    );
  }
}

// ── Tree card ─────────────────────────────────────────────────────────────────

class _TreeCard extends StatelessWidget {
  const _TreeCard({
    required this.tree,
    required this.stage,
    required this.t,
    required this.onTap,
  });

  final TreeModel tree;
  final GrowthStage stage;
  final AppText t;
  final VoidCallback onTap;

  static Color _stageColor(GrowthStage s) => switch (s) {
        GrowthStage.planted => const Color(0xFF4CAF50),
        GrowthStage.sprouting => const Color(0xFF81C784),
        GrowthStage.growing => ColorConstants.forestGreen,
        GrowthStage.established => const Color(0xFF2E7D32),
        GrowthStage.needsAttention => ColorConstants.warningColor,
        GrowthStage.dead => ColorConstants.errorColor,
      };

  String _stageName(GrowthStage s) => switch (s) {
        GrowthStage.planted => t.stagePlanted,
        GrowthStage.sprouting => t.stageSprouting,
        GrowthStage.growing => t.stageGrowing,
        GrowthStage.established => t.stageEstablished,
        GrowthStage.needsAttention => t.stageNeedsAttention,
        GrowthStage.dead => t.stageDead,
      };

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    final planted = tree.plantingDate;
    final days =
        planted != null ? DateTime.now().difference(planted).inDays : null;
    final plantedStr =
        planted != null ? DateFormat('dd MMM yyyy').format(planted) : '—';

    return OmEarthCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ColorConstants.veryPaleGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              ImageConstants.matureTree,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tree.species ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${t.plantedOn}  $plantedStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorConstants.mutedText,
                  ),
                ),
                if (days != null)
                  Text(
                    '$days ${t.daysGrowing}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorConstants.mutedText,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OmEarthStatusChip(
                label: _stageName(stage),
                color: color,
              ),
              const SizedBox(height: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: ColorConstants.mutedText,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
