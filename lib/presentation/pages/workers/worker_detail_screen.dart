import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/tree_growth_update_model.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/data/repositories/tree_growth_repository.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/data/repositories/worker_plot_repository.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';
import 'package:mess_app/presentation/pages/worker/worker_tree_detail_screen.dart';
import 'package:mess_app/presentation/pages/workers/add_worker_screen.dart';
import 'package:mess_app/presentation/widgets/plot_assignment_picker.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';
import 'package:mess_app/core/service_locator/di.dart';

/// Full detail view for a single field volunteer — plots, tree updates,
/// recent registrations, and active/inactive toggle.
class WorkerDetailScreen extends StatefulWidget {
  const WorkerDetailScreen({
    super.key,
    required this.workerId,
    required this.t,
  });

  final String workerId;
  final AppText t;

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final _repo = getIt<WorkerRepository>();
  final _plotAssignRepo = getIt<WorkerPlotRepository>();
  final _plotRepo = getIt<PlotRepository>();
  final _growthRepo = getIt<TreeGrowthRepository>();
  final _treeRepo = getIt<TreeRepository>();

  WorkerModel? _worker;
  List<PlotModel> _assignedPlots = [];
  List<Map<String, dynamic>> _recentTrees = [];
  List<WorkerTreeGrowthUpdate> _treeUpdates = [];
  int _totalTrees = 0;
  int _todayTrees = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final worker = await _repo.getById(widget.workerId);
    final plots = await _plotAssignRepo.getPlotsForWorker(widget.workerId);
    final trees = await _repo.getTreesByWorker(widget.workerId);
    final total = await _repo.getTotalTreesByWorker(widget.workerId);
    final today = await _repo.getTodayTreesByWorker(widget.workerId);
    final updates = await _growthRepo.getForWorker(widget.workerId);
    if (!mounted) return;
    setState(() {
      _worker = worker;
      _assignedPlots = plots;
      _recentTrees = trees;
      _treeUpdates = updates;
      _totalTrees = total;
      _todayTrees = today;
      _loading = false;
    });
  }

  Future<void> _openTree(String treeId) async {
    final navigator = Navigator.of(context);
    final tree = await _treeRepo.getById(treeId);
    if (!mounted || tree == null) return;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => WorkerTreeDetailScreen(
          tree: tree,
          workerId: widget.workerId,
          readOnly: true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _toggleActive() async {
    final worker = _worker;
    if (worker == null) return;
    // Cache cubit before the async gap.
    final cubit = context.read<WorkersCubit>();
    await cubit.toggleActiveStatus(worker.id, isActive: !worker.isActive);
    await _load();
  }

  Future<void> _openEdit() async {
    final worker = _worker;
    if (worker == null) return;
    final cubit = context.read<WorkersCubit>();
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddWorkerScreen(
          t: widget.t,
          cubit: cubit,
          worker: worker,
        ),
      ),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _removePlot(PlotModel plot) async {
    final cubit = context.read<WorkersCubit>();
    await _plotAssignRepo.unassign(widget.workerId, plot.id);
    cubit.load();
    await _load();
    if (!mounted) return;
    SnackbarHelper.showSucces(
      context: context,
      message: widget.t.plotRemoved,
    );
  }

  Future<void> _openManagePlots() async {
    final t = widget.t;
    final cubit = context.read<WorkersCubit>();
    final allPlots = await _plotRepo.getAssignedPlots();
    if (!mounted) return;

    var selected = _assignedPlots.map((p) => p.id).toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorConstants.lightBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.75;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.managePlots,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ColorConstants.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight - 120),
                    child: SingleChildScrollView(
                      child: PlotAssignmentPicker(
                        t: t,
                        plots: allPlots,
                        selectedPlotIds: selected,
                        onChanged: (ids) =>
                            setSheetState(() => selected = ids),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: t.saveChanges,
                    icon: Icons.check_rounded,
                    onPressed: () async {
                      final ok = await cubit.updateWorkerPlots(
                        widget.workerId,
                        selected.toList(),
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      if (ok) {
                        await _load();
                        if (!mounted) return;
                        SnackbarHelper.showSucces(
                          context: this.context,
                          message: t.plotsUpdated,
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    return Scaffold(
      backgroundColor: ColorConstants.lightBackgroundSecondary,
      appBar: AppBar(
        backgroundColor: ColorConstants.lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: ColorConstants.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.workerDetail,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
        actions: [
          if (_worker != null) ...[
            IconButton(
              tooltip: t.edit,
              onPressed: _openEdit,
              icon: const Icon(
                Icons.edit_rounded,
                color: ColorConstants.forestGreen,
              ),
            ),
            TextButton(
              onPressed: _toggleActive,
              child: Text(
                _worker!.isActive ? t.deactivate : t.activate,
                style: TextStyle(
                  color: _worker!.isActive
                      ? ColorConstants.errorColor
                      : ColorConstants.forestGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ColorConstants.forestGreen,
                ),
              ),
            )
          : _worker == null
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  color: ColorConstants.forestGreen,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _ProfileCard(t: t, worker: _worker!),
                      const SizedBox(height: 16),
                      _StatsRow(
                        t: t,
                        todayTrees: _todayTrees,
                        totalTrees: _totalTrees,
                        joinedAt: _worker!.createdAt,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _SectionLabel(text: t.assignedPlots),
                          ),
                          TextButton.icon(
                            onPressed: _openManagePlots,
                            icon: const Icon(
                              Icons.edit_location_alt_outlined,
                              size: 18,
                            ),
                            label: Text(t.managePlots),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_assignedPlots.isEmpty)
                        _EmptyPlots(t: t)
                      else
                        ..._assignedPlots.map(
                          (plot) => _AssignedPlotRow(
                            t: t,
                            plot: plot,
                            onRemove: () => _removePlot(plot),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _SectionLabel(text: t.treeUpdates),
                      const SizedBox(height: 12),
                      if (_treeUpdates.isEmpty)
                        _EmptyTreeUpdates(t: t)
                      else
                        ..._treeUpdates.map(
                          (item) => _GrowthUpdateRow(
                            t: t,
                            item: item,
                            onTap: () => _openTree(item.update.treeId),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _SectionLabel(text: t.recentActivity),
                      const SizedBox(height: 12),
                      if (_recentTrees.isEmpty)
                        _EmptyActivity(t: t)
                      else
                        ..._recentTrees.map(
                          (row) => _TreeRow(
                            t: t,
                            row: row,
                            onTap: () => _openTree(row['id'] as String),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.t, required this.worker});
  final AppText t;
  final WorkerModel worker;

  @override
  Widget build(BuildContext context) {
    final active = worker.isActive;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: active
                  ? ColorConstants.forestGreen.withValues(alpha: 0.15)
                  : ColorConstants.lightSurfaceDark,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              worker.initials,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: active
                    ? ColorConstants.forestGreen
                    : ColorConstants.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        worker.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: ColorConstants.lightTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(active: active, t: t),
                  ],
                ),
                if (worker.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    worker.phone!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active, required this.t});
  final bool active;
  final AppText t;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? ColorConstants.successColor : ColorConstants.lightTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        active ? t.active : t.inactive,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.t,
    required this.todayTrees,
    required this.totalTrees,
    required this.joinedAt,
  });

  final AppText t;
  final int todayTrees;
  final int totalTrees;
  final DateTime joinedAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            value: '$todayTrees',
            label: t.treesToday,
            color: todayTrees > 0
                ? ColorConstants.forestGreen
                : ColorConstants.lightTextSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            value: '$totalTrees',
            label: t.totalTrees,
            color: ColorConstants.infoColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            value: _shortDate(joinedAt),
            label: t.joinedOn,
            color: ColorConstants.primaryOrange,
          ),
        ),
      ],
    );
  }

  String _shortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: ColorConstants.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ColorConstants.lightTextPrimary,
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Center(
        child: Text(
          t.notActiveToday,
          style: const TextStyle(
            color: ColorConstants.lightTextSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Tree row ──────────────────────────────────────────────────────────────────

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.t,
    required this.row,
    required this.onTap,
  });

  final AppText t;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final species = (row['species'] as String?) ?? '—';
    final plotId = (row['plot_id'] as String?) ?? '—';
    final ms = row['created_at'] as int?;
    final dt = ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorConstants.borderGrey),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorConstants.softGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.park_outlined,
                    size: 18,
                    color: ColorConstants.forestGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        species,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorConstants.lightTextPrimary,
                        ),
                      ),
                      Text(
                        plotId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ColorConstants.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dt != null)
                  Text(
                    _timeLabel(dt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorConstants.lightTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _EmptyTreeUpdates extends StatelessWidget {
  const _EmptyTreeUpdates({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Text(
        t.noTreeUpdates,
        style: const TextStyle(
          color: ColorConstants.lightTextSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _GrowthUpdateRow extends StatelessWidget {
  const _GrowthUpdateRow({
    required this.t,
    required this.item,
    required this.onTap,
  });

  final AppText t;
  final WorkerTreeGrowthUpdate item;
  final VoidCallback onTap;

  String _stageName(GrowthStage stage) => switch (stage) {
        GrowthStage.planted => t.stagePlanted,
        GrowthStage.sprouting => t.stageSprouting,
        GrowthStage.growing => t.stageGrowing,
        GrowthStage.established => t.stageEstablished,
        GrowthStage.needsAttention => t.stageNeedsAttention,
        GrowthStage.dead => t.stageDead,
      };

  (IconData, Color) _stageStyle(GrowthStage stage) => switch (stage) {
        GrowthStage.planted => (Icons.eco_rounded, const Color(0xFF4CAF50)),
        GrowthStage.sprouting =>
          (Icons.nature_rounded, const Color(0xFF81C784)),
        GrowthStage.growing =>
          (Icons.park_rounded, ColorConstants.forestGreen),
        GrowthStage.established =>
          (Icons.forest_rounded, const Color(0xFF2E7D32)),
        GrowthStage.needsAttention =>
          (Icons.warning_amber_rounded, ColorConstants.warningColor),
        GrowthStage.dead => (
            Icons.sentiment_very_dissatisfied_rounded,
            ColorConstants.errorColor,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final update = item.update;
    final (icon, color) = _stageStyle(update.stage);
    final stage = _stageName(update.stage);
    final height = update.heightCm;
    final notes = update.notes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorConstants.borderGrey),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.species ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        stage,
                        if (height != null) t.heightLabel(height),
                        item.plotId,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ColorConstants.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeLabel(update.recordedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: ColorConstants.lightTextSecondary,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorConstants.lightTextSecondary,
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _EmptyPlots extends StatelessWidget {
  const _EmptyPlots({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Text(
        t.noPlotsAssigned,
        style: const TextStyle(
          color: ColorConstants.lightTextSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _AssignedPlotRow extends StatelessWidget {
  const _AssignedPlotRow({
    required this.t,
    required this.plot,
    required this.onRemove,
  });

  final AppText t;
  final PlotModel plot;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorConstants.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.place_outlined,
              size: 18,
              color: ColorConstants.forestGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plot.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
                Text(
                  plot.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: ColorConstants.errorColor,
            ),
            tooltip: t.plotRemoved,
          ),
        ],
      ),
    );
  }
}
