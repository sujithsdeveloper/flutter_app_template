import 'package:flutter/material.dart';
import '../tasks/corporate_plantation_screen.dart';
import 'package:intl/intl.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';
import 'package:mess_app/data/repositories/worker_plot_repository.dart';
import 'package:mess_app/presentation/pages/plots/plot_detail_screen.dart';
import 'package:mess_app/presentation/pages/worker/task_update_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

/// Personal dashboard for a field volunteer — mirrors the admin home layout
/// with role-appropriate sections (no sync banner, workers list, or add-plot).
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({
    super.key,
    required this.session,
    this.onViewAllTasks,
  });

  final UserSession session;
  final VoidCallback? onViewAllTasks;

  @override
  WorkerHomeScreenState createState() => WorkerHomeScreenState();
}

class WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final _taskRepo = getIt<TreeTaskRepository>();
  final _treeRepo = getIt<TreeRepository>();
  final _plotAssignRepo = getIt<WorkerPlotRepository>();
  final _scrollController = ScrollController();
  final _tasksSectionKey = GlobalKey();

  List<TreeTaskModel> _tasks = [];
  List<PlotModel> _plots = [];
  int _treesToday = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTasks() {
    final ctx = _tasksSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _load() async {
    final tasks = await _taskRepo.getByWorkerId(widget.session.userId);
    final trees = await _treeRepo.getRegisteredTodayByWorker(
      widget.session.userId,
    );
    final plots = await _plotAssignRepo.getPlotsForWorker(
      widget.session.userId,
    );
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _plots = plots;
      _treesToday = trees;
      _loading = false;
    });
  }

  TreeTaskModel? _pickFeaturedTask() {
    final actionable = _tasks
        .where((task) => task.taskStatus.isActionable)
        .toList();
    if (actionable.isEmpty) return null;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todayTasks = actionable.where((task) {
      final date = task.targetDate;
      if (date == null) return false;
      return !date.isBefore(todayStart) && date.isBefore(todayEnd);
    }).toList();
    if (todayTasks.isNotEmpty) return todayTasks.first;

    final due = actionable.where((task) => task.isDue).toList();
    if (due.isNotEmpty) return due.first;

    return actionable.first;
  }

  int get _actionableCount => _tasks
      .where(
        (t) =>
            t.taskStatus == TaskStatus.pending ||
            t.taskStatus == TaskStatus.assigned,
      )
      .length;

  int get _plantedCount =>
      _tasks.where((t) => t.taskStatus == TaskStatus.planted).length;

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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ColorConstants.forestGreen,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: ColorConstants.forestGreen,
                    backgroundColor: ColorConstants.cardSurface,
                    onRefresh: _load,
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        omEarthBottomScrollPadding(context),
                      ),
                      children: [
                        _Header(t: t, lang: lang, session: widget.session),
                        const SizedBox(height: 20),
                        _FieldWorkHero(
                          t: t,
                          plots: _plots,
                          featuredTask: _pickFeaturedTask(),
                          onViewAll: widget.onViewAllTasks,
                          onTaskTap: (task) => _openTask(context, task),
                        ),
                        const SizedBox(height: 28),
                        OmEarthSectionHeader(
                          title: t.overviewTitle,
                          showLeafIcon: true,
                        ),
                        const SizedBox(height: 14),
                        _OverviewSummary(
                          t: t,
                          treesToday: _treesToday,
                          actionableCount: _actionableCount,
                          plantedCount: _plantedCount,
                          plotCount: _plots.length,
                        ),
                        const SizedBox(height: 28),
                        OmEarthSectionHeader(
                          key: _tasksSectionKey,
                          title: t.myTasks,
                          actionLabel: _tasks.length > 3 ? t.viewAll : null,
                          onAction: _tasks.length > 3
                              ? widget.onViewAllTasks
                              : null,
                          showLeafIcon: true,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CorporatePlantationScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.forest_outlined),
                          label: const Text('Corporate planting batches'),
                        ),
                        _TasksList(
                          t: t,
                          tasks: _tasks,
                          onTap: (task) => _openTask(context, task),
                        ),
                        const SizedBox(height: 28),
                        OmEarthSectionHeader(
                          title: t.myPlots,
                          showLeafIcon: true,
                        ),
                        const SizedBox(height: 14),
                        _PlotsMiniList(
                          t: t,
                          plots: _plots,
                          onTapPlot: (plot) => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlotDetailScreen(plot: plot, t: t),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openTask(BuildContext context, TreeTaskModel task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskUpdateScreen(task: task, session: widget.session),
      ),
    );
    await _load();
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.t, required this.lang, required this.session});

  final AppText t;
  final AppLanguage lang;
  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final displayName = session.userName.trim();
    final initials = displayName.isNotEmpty
        ? _initialsFromName(displayName)
        : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -6,
              left: 6,
              child: Image.asset(
                ImageConstants.leafSprig,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
            ),
            OmEarthAvatar(initials: initials, size: 52),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.greeting(hour),
                style: const TextStyle(
                  fontSize: 13,
                  color: ColorConstants.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (displayName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.forestGreen,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _RoleChip(t: t),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _NotificationBell(),
            const SizedBox(height: 8),
            _LanguageToggle(lang: lang),
          ],
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: ColorConstants.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorConstants.cardBorder, width: 0.7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.notifications_outlined,
            size: 22,
            color: ColorConstants.forestGreen,
          ),
          Positioned(
            top: 10,
            right: 11,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: ColorConstants.successColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.t});

  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ColorConstants.rolePillBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.eco_rounded,
            size: 14,
            color: ColorConstants.rolePillText,
          ),
          const SizedBox(width: 5),
          Text(
            t.roleVolunteer,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ColorConstants.rolePillText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final isEnglish = lang == AppLanguage.english;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: LanguageController.toggle,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: ColorConstants.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorConstants.cardBorder, width: 0.7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'മലയാളം',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isEnglish ? FontWeight.w500 : FontWeight.w700,
                  color: isEnglish
                      ? ColorConstants.mutedText
                      : ColorConstants.forestGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorConstants.mutedText.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Text(
                'EN',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isEnglish ? FontWeight.w700 : FontWeight.w500,
                  color: isEnglish
                      ? ColorConstants.forestGreen
                      : ColorConstants.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Field work hero ───────────────────────────────────────────────────────────

class _FieldWorkHero extends StatelessWidget {
  const _FieldWorkHero({
    required this.t,
    required this.plots,
    required this.featuredTask,
    required this.onViewAll,
    required this.onTaskTap,
  });

  final AppText t;
  final List<PlotModel> plots;
  final TreeTaskModel? featuredTask;
  final VoidCallback? onViewAll;
  final ValueChanged<TreeTaskModel> onTaskTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.forestGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.forestGreen.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  ImageConstants.seedling,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.todayFieldWork,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      t.todayFieldWorkSub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              if (onViewAll != null)
                Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onViewAll,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.viewAllTasks,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (featuredTask != null)
            _FieldWorkTaskCard(
              t: t,
              task: featuredTask!,
              plots: plots,
              onTap: () => onTaskTap(featuredTask!),
            )
          else
            _FieldWorkEmpty(t: t),
        ],
      ),
    );
  }
}

class _FieldWorkEmpty extends StatelessWidget {
  const _FieldWorkEmpty({required this.t});

  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorConstants.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Image.asset(
            ImageConstants.wateringSeedling,
            height: 56,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Text(
            t.noTasksAssigned,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorConstants.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.noTasksHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: ColorConstants.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldWorkTaskCard extends StatelessWidget {
  const _FieldWorkTaskCard({
    required this.t,
    required this.task,
    required this.plots,
    required this.onTap,
  });

  final AppText t;
  final TreeTaskModel task;
  final List<PlotModel> plots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plot = _findPlot(task.plotId, plots);
    final plotLabel = plot?.name ?? task.locationLabel;
    final treeCount = plot?.treeCount ?? 0;
    final areaHectares = plot?.areaHectares;
    final hasStats = plot != null && (treeCount > 0 || areaHectares != null);

    return Material(
      color: ColorConstants.cardSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                ImageConstants.wateringSeedling,
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.species.isNotEmpty ? task.species : t.planting,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorConstants.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plotLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (task.targetDate != null) ...[
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: ColorConstants.mutedText,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatTaskTime(t, task.targetDate!),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ColorConstants.mutedText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: _TaskStatusChip(status: task.taskStatus, t: t),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasStats) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 72,
                  color: ColorConstants.border.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (treeCount > 0) ...[
                      Row(
                        children: [
                          Image.asset(
                            ImageConstants.leafSprig,
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t.treesStat(treeCount),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: ColorConstants.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (areaHectares != null)
                      Text(
                        t.areaStat(areaHectares),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: ColorConstants.primaryText,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({required this.status, required this.t});

  final TaskStatus status;
  final AppText t;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaskStatus.pending => (t.taskStatusPending, ColorConstants.warningColor),
      TaskStatus.assigned => (t.assigned, ColorConstants.infoColor),
      TaskStatus.planted => (t.planted, ColorConstants.successColor),
      TaskStatus.cancelled => ('Cancelled', ColorConstants.mutedText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Overview ──────────────────────────────────────────────────────────────────

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({
    required this.t,
    required this.treesToday,
    required this.actionableCount,
    required this.plantedCount,
    required this.plotCount,
  });

  final AppText t;
  final int treesToday;
  final int actionableCount;
  final int plantedCount;
  final int plotCount;

  @override
  Widget build(BuildContext context) {
    return OmEarthOverviewMetricGrid(
      children: [
        OmEarthOverviewMetricCard(
          value: '$treesToday',
          label: t.statTreesToday,
          illustrationAsset: ImageConstants.seedling,
          accentColor: ColorConstants.forestGreen,
        ),
        OmEarthOverviewMetricCard(
          value: '$actionableCount',
          label: t.tasksAssigned,
          illustrationAsset: ImageConstants.pendingTask,
          accentColor: actionableCount > 0
              ? ColorConstants.warningColor
              : ColorConstants.infoColor,
        ),
        OmEarthOverviewMetricCard(
          value: '$plantedCount',
          label: t.planted,
          illustrationAsset: ImageConstants.matureTree,
          accentColor: ColorConstants.successColor,
        ),
        OmEarthOverviewMetricCard(
          value: '$plotCount',
          label: t.myPlots,
          illustrationAsset: ImageConstants.leafSprig,
          accentColor: plotCount > 0
              ? ColorConstants.forestGreen
              : ColorConstants.mutedText,
        ),
      ],
    );
  }
}

// ── Tasks list ────────────────────────────────────────────────────────────────

class _TasksList extends StatelessWidget {
  const _TasksList({required this.t, required this.tasks, required this.onTap});

  final AppText t;
  final List<TreeTaskModel> tasks;
  final ValueChanged<TreeTaskModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return OmEarthCard(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        radius: 20,
        showShadow: false,
        child: Column(
          children: [
            Image.asset(
              ImageConstants.pendingTask,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              t.noTasksAssigned,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorConstants.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.noTasksHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: ColorConstants.mutedText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < tasks.length; i++) ...[
          _TaskMiniRow(t: t, task: tasks[i], onTap: () => onTap(tasks[i])),
          if (i < tasks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TaskMiniRow extends StatelessWidget {
  const _TaskMiniRow({
    required this.t,
    required this.task,
    required this.onTap,
  });

  final AppText t;
  final TreeTaskModel task;
  final VoidCallback onTap;

  Color get _color => switch (task.taskStatus) {
    TaskStatus.pending => ColorConstants.warningColor,
    TaskStatus.assigned => ColorConstants.infoColor,
    TaskStatus.planted => ColorConstants.successColor,
    TaskStatus.cancelled => ColorConstants.mutedText,
  };

  String _statusLabel() => switch (task.taskStatus) {
    TaskStatus.pending => t.unassigned,
    TaskStatus.assigned => t.assigned,
    TaskStatus.planted => t.planted,
    TaskStatus.cancelled => 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    return OmEarthCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 20,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(ImageConstants.seedling, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.species.isNotEmpty ? task.species : t.planting,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: ColorConstants.secondaryGreen,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        task.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ColorConstants.secondaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OmEarthStatusChip(label: _statusLabel(), color: _color),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: ColorConstants.mutedText,
          ),
        ],
      ),
    );
  }
}

// ── Plots ─────────────────────────────────────────────────────────────────────

class _PlotsMiniList extends StatelessWidget {
  const _PlotsMiniList({
    required this.t,
    required this.plots,
    required this.onTapPlot,
  });

  final AppText t;
  final List<PlotModel> plots;
  final ValueChanged<PlotModel> onTapPlot;

  @override
  Widget build(BuildContext context) {
    if (plots.isEmpty) {
      return OmEarthCard(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        radius: 20,
        showShadow: false,
        child: Column(
          children: [
            Image.asset(
              ImageConstants.seedling,
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Text(
              t.noPlotsAssigned,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorConstants.primaryText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < plots.length; i++) ...[
          _PlotMiniRow(t: t, plot: plots[i], onTap: () => onTapPlot(plots[i])),
          if (i < plots.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlotMiniRow extends StatelessWidget {
  const _PlotMiniRow({
    required this.t,
    required this.plot,
    required this.onTap,
  });

  final AppText t;
  final PlotModel plot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = switch (plot.status) {
      PlotStatus.healthy => (t.statusHealthy, ColorConstants.successColor),
      PlotStatus.needsCheck => (
        t.statusNeedsCheck,
        ColorConstants.warningColor,
      ),
      PlotStatus.inspectionDue => (
        t.statusInspectionDue,
        ColorConstants.infoColor,
      ),
    };

    return OmEarthCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 20,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorConstants.veryPaleGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(ImageConstants.matureTree, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plot.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ColorConstants.secondaryText,
                  ),
                ),
                if (plot.areaHectares != null || plot.treeCount > 0)
                  Text(
                    [
                      if (plot.treeCount > 0) t.treesCount(plot.treeCount),
                      if (plot.areaHectares != null)
                        '${plot.areaHectares!.toStringAsFixed(1)} ha',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: ColorConstants.mutedText,
                    ),
                  ),
              ],
            ),
          ),
          OmEarthStatusChip(label: status.$1, color: status.$2),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initialsFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
}

PlotModel? _findPlot(String plotId, List<PlotModel> plots) {
  for (final plot in plots) {
    if (plot.id == plotId) return plot;
  }
  return null;
}

String _formatTaskTime(AppText t, DateTime date) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final time = DateFormat('h:mm a').format(date);

  if (!date.isBefore(todayStart) && date.isBefore(todayEnd)) {
    return t.todayAt(time);
  }
  return DateFormat('MMM d, h:mm a').format(date);
}
