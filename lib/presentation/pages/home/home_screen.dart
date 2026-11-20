import 'package:flutter/material.dart';
import '../trees/field_campaigns_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_cubit.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_state.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';
import 'package:mess_app/presentation/blocs/workers/workers_state.dart';
import 'package:mess_app/presentation/pages/plots/plot_detail_screen.dart';
import 'package:mess_app/presentation/pages/workers/worker_detail_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';
import 'package:mess_app/presentation/widgets/volunteer_admin_label.dart';

/// Home / Dashboard for volunteer (admin) users.
///
/// All data originates from [DashboardCubit] which reads [AppDatabase] — no
/// mocked values, no hardcoded lists. The bilingual label switch drives every
/// string through [AppText] so the entire screen flips to Malayalam on one tap.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenTab});

  /// Lets quick-action cards jump to the matching bottom-nav tab.
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<DashboardCubit, DashboardState>(
          listenWhen: (prev, curr) => curr.syncJobStatus != prev.syncJobStatus,
          listener: (context, state) {
            if (state.syncJobStatus == SyncJobStatus.succeeded) {
              // Cubits are created at app root before login/sync — refresh
              // local task/worker lists after SQLite is replaced.
              context.read<TreeTasksCubit>().load();
              context.read<WorkersCubit>().load();
              return;
            }
            if (state.syncJobStatus == SyncJobStatus.failed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ??
                        'Sync failed. Will retry when online.',
                  ),
                  backgroundColor: ColorConstants.errorColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, dashState) {
            return ValueListenableBuilder<AppLanguage>(
              valueListenable: LanguageController.language,
              builder: (context, lang, _) {
                final t = AppText(lang);
                return RefreshIndicator(
                  color: ColorConstants.forestGreen,
                  backgroundColor: ColorConstants.cardSurface,
                  onRefresh: () => context.read<DashboardCubit>().triggerSync(),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      omEarthBottomScrollPadding(context),
                    ),
                    children: [
                      _Header(t: t, lang: lang),
                      const SizedBox(height: 20),
                      _SyncBanner(
                        t: t,
                        dashState: dashState,
                        onSync: () =>
                            context.read<DashboardCubit>().triggerSync(),
                      ),
                      const SizedBox(height: 24),
                      _FieldWorkHero(
                        t: t,
                        plots: dashState.plots,
                        onViewAll: () => onOpenTab?.call(3),
                      ),
                      const SizedBox(height: 28),
                      OmEarthSectionHeader(
                        title: t.overviewTitle,
                        showLeafIcon: true,
                      ),
                      const SizedBox(height: 14),
                      _OverviewSummary(t: t, dashState: dashState),
                      const SizedBox(height: 28),
                      OmEarthSectionHeader(
                        title: t.quickActions,
                        showLeafIcon: true,
                      ),
                      const SizedBox(height: 14),
                      _QuickActions(t: t, onOpenTab: onOpenTab),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FieldCampaignsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.forest_outlined),
                        label: const Text(
                          'Corporate campaigns and allocations',
                        ),
                      ),

                      const SizedBox(height: 28),
                      _WorkersSectionHeader(
                        t: t,
                        count: dashState.workerCount,
                        activeToday: dashState.activeWorkersToday,
                        onViewAll: () => onOpenTab?.call(2),
                      ),
                      const SizedBox(height: 14),
                      _WorkersMiniList(
                        t: t,
                        workers: dashState.topWorkers,
                        onTap: (id) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkerDetailScreen(workerId: id, t: t),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      OmEarthSectionHeader(
                        title: t.myPlots,
                        actionLabel: t.viewAll,
                        onAction: () => onOpenTab?.call(1),
                        showLeafIcon: true,
                      ),
                      const SizedBox(height: 14),
                      _PlotsMiniList(
                        t: t,
                        plots: dashState.plots,
                        onTapPlot: (plot) => _openPlotDetail(context, t, plot),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

void _openPlotDetail(BuildContext context, AppText t, PlotModel plot) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => PlotDetailScreen(plot: plot, t: t),
    ),
  );
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

TreeTaskModel? _pickFeaturedTask(List<TreeTaskModel> tasks) {
  final actionable = tasks
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

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
  const _Header({required this.t, required this.lang});

  final AppText t;
  final AppLanguage lang;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  UserSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await getIt<SessionManager>().getSession();
    if (!mounted) return;
    setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final displayName = _session?.userName.trim() ?? '';
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
                widget.t.greeting(hour),
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
              _RoleChip(t: widget.t),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _NotificationBell(),
            const SizedBox(height: 8),
            _LanguageToggle(lang: widget.lang),
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
            Icons.verified_rounded,
            size: 14,
            color: ColorConstants.rolePillText,
          ),
          const SizedBox(width: 5),
          VolunteerAdminLabel(
            t: t,
            baseStyle: const TextStyle(
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

// ── Sync banner ───────────────────────────────────────────────────────────────

enum _BannerVariant { offline, pendingUpload, syncing, synced }

_BannerVariant _toBannerVariant(DashboardState s) {
  if (s.syncJobStatus == SyncJobStatus.running) return _BannerVariant.syncing;
  if (!s.isOnline) return _BannerVariant.offline;
  if (s.pendingSync > 0) return _BannerVariant.pendingUpload;
  return _BannerVariant.synced;
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.t,
    required this.dashState,
    required this.onSync,
  });

  final AppText t;
  final DashboardState dashState;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final variant = _toBannerVariant(dashState);

    late final Color accent;
    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final bool showButton;

    switch (variant) {
      case _BannerVariant.offline:
        accent = ColorConstants.warningColor;
        icon = Icons.cloud_off_rounded;
        title = t.syncOffline;
        subtitle = dashState.pendingSync > 0
            ? t.pendingRecords(dashState.pendingSync)
            : t.allSafe;
        showButton = false;
      case _BannerVariant.pendingUpload:
        accent = ColorConstants.warningColor;
        icon = Icons.cloud_upload_outlined;
        title = t.syncPendingUpload;
        subtitle = t.pendingRecords(dashState.pendingSync);
        showButton = true;
      case _BannerVariant.syncing:
        accent = ColorConstants.infoColor;
        icon = Icons.sync_rounded;
        title = t.syncSyncing;
        subtitle = t.syncingNow;
        showButton = true;
      case _BannerVariant.synced:
        accent = ColorConstants.successColor;
        icon = Icons.cloud_done_rounded;
        title = t.syncSynced;
        subtitle = dashState.lastSyncTime != null
            ? t.lastSynced(_formatSyncTime(dashState.lastSyncTime!))
            : t.syncNeverSynced;
        showButton = false;
    }

    return OmEarthCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 14),
      radius: 22,
      showShadow: true,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: -8,
            bottom: -8,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              child: Image.asset(
                ImageConstants.matureTree,
                // width: 130,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ColorConstants.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (showButton) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: OmEarthPrimaryButton(
                    label: t.syncNow,
                    compact: true,
                    isLoading: variant == _BannerVariant.syncing,
                    onPressed: variant == _BannerVariant.syncing
                        ? null
                        : onSync,
                  ),
                ),
              ] else
                const SizedBox(width: 100),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSyncTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Today's field work hero ───────────────────────────────────────────────────

class _FieldWorkHero extends StatelessWidget {
  const _FieldWorkHero({
    required this.t,
    required this.plots,
    required this.onViewAll,
  });

  final AppText t;
  final List<PlotModel> plots;
  final VoidCallback onViewAll;

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
          BlocBuilder<TreeTasksCubit, TreeTasksState>(
            builder: (context, taskState) {
              if (taskState is TreeTasksLoaded) {
                final task = _pickFeaturedTask(taskState.tasks);
                if (task != null) {
                  return _FieldWorkTaskCard(t: t, task: task, plots: plots);
                }
              }
              return _FieldWorkEmpty(t: t);
            },
          ),
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
            t.noTasksYet,
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

class _FieldWorkTaskCard extends StatefulWidget {
  const _FieldWorkTaskCard({
    required this.t,
    required this.task,
    required this.plots,
  });

  final AppText t;
  final TreeTaskModel task;
  final List<PlotModel> plots;

  @override
  State<_FieldWorkTaskCard> createState() => _FieldWorkTaskCardState();
}

class _FieldWorkTaskCardState extends State<_FieldWorkTaskCard> {
  String? _workerName;

  @override
  void initState() {
    super.initState();
    _loadWorkerName();
  }

  Future<void> _loadWorkerName() async {
    final workerId = widget.task.workerId;
    if (workerId == null) return;

    final workersState = context.read<WorkersCubit>().state;
    if (workersState is WorkersLoaded) {
      for (final stats in workersState.workers) {
        if (stats.worker.id == workerId) {
          setState(() => _workerName = stats.worker.name);
          return;
        }
      }
    }

    final worker = await getIt<WorkerRepository>().getById(workerId);
    if (!mounted) return;
    setState(() => _workerName = worker?.name);
  }

  @override
  Widget build(BuildContext context) {
    final plot = _findPlot(widget.task.plotId, widget.plots);
    final plotLabel = plot?.name ?? widget.task.plotId;
    final treeCount = plot?.treeCount ?? 0;
    final areaHectares = plot?.areaHectares;
    final hasStats = plot != null && (treeCount > 0 || areaHectares != null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorConstants.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
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
                  widget.task.species.isNotEmpty
                      ? widget.task.species
                      : widget.t.planting,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.forestGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.task.displaySponsorIntent(widget.t.sponsorIntentFor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.primaryText,
                  ),
                ),
                if (widget.task.regionName != null &&
                    widget.task.regionName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.task.regionName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorConstants.mutedText,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(
                    plotLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorConstants.mutedText,
                    ),
                  ),
                ],
                if (_workerName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.t.assignedToWorker(_workerName!),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorConstants.mutedText,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.task.targetDate != null) ...[
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: ColorConstants.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _formatTaskTime(widget.task.targetDate!),
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
                      child: _TaskStatusChip(
                        status: widget.task.taskStatus,
                        t: widget.t,
                      ),
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
                        widget.t.treesStat(treeCount),
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
                    widget.t.areaStat(areaHectares),
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
    );
  }

  String _formatTaskTime(DateTime date) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final time = DateFormat('h:mm a').format(date);

    if (!date.isBefore(todayStart) && date.isBefore(todayEnd)) {
      return widget.t.todayAt(time);
    }
    return DateFormat('MMM d, h:mm a').format(date);
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

// ── Operations overview ───────────────────────────────────────────────────────

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({required this.t, required this.dashState});

  final AppText t;
  final DashboardState dashState;

  @override
  Widget build(BuildContext context) {
    return OmEarthOverviewMetricGrid(
      children: [
        OmEarthOverviewMetricCard(
          value: '${dashState.treesRegisteredToday}',
          label: t.statTreesToday,
          illustrationAsset: ImageConstants.seedling,
          accentColor: ColorConstants.forestGreen,
        ),
        OmEarthOverviewMetricCard(
          value: '${dashState.workerCount}',
          label: t.workers,
          illustrationAsset: ImageConstants.volunteerTeam,
          accentColor: ColorConstants.infoColor,
        ),
        OmEarthOverviewMetricCard(
          value: '${dashState.pendingTasksCount}',
          label: t.pendingTasks,
          illustrationAsset: ImageConstants.pendingTask,
          accentColor: dashState.pendingTasksCount > 0
              ? ColorConstants.warningColor
              : ColorConstants.successColor,
        ),
        OmEarthOverviewMetricCard(
          value: '${dashState.pendingSync}',
          label: t.statPendingSync,
          illustrationAsset: ImageConstants.leafSprig,
          accentColor: dashState.pendingSync > 0
              ? ColorConstants.warningColor
              : ColorConstants.successColor,
        ),
      ],
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.t, required this.onOpenTab});

  final AppText t;
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.qr_code_2_rounded,
            title: t.generateQr,
            subtitle: t.generateQrSub,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.straighten_rounded,
            title: t.inspectTree,
            subtitle: t.inspectTreeSub,
            onTap: () => onOpenTab?.call(3),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OmEarthCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Row(
        children: [
          OmEarthIconBadge(
            icon: icon,
            color: ColorConstants.forestGreen,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: ColorConstants.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: ColorConstants.mutedText,
          ),
        ],
      ),
    );
  }
}

// ── Workers section ───────────────────────────────────────────────────────────

class _WorkersSectionHeader extends StatelessWidget {
  const _WorkersSectionHeader({
    required this.t,
    required this.count,
    required this.activeToday,
    required this.onViewAll,
  });

  final AppText t;
  final int count;
  final int activeToday;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          t.workers,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ColorConstants.primaryText,
            letterSpacing: -0.3,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ColorConstants.paleGreen,
              borderRadius: BorderRadius.circular(10),
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
        if (activeToday > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ColorConstants.forestGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              t.activeCount(activeToday),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onViewAll,
          child: Row(
            children: [
              Text(
                t.viewAll,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorConstants.forestGreen,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorConstants.forestGreen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkersMiniList extends StatelessWidget {
  const _WorkersMiniList({
    required this.t,
    required this.workers,
    required this.onTap,
  });

  final AppText t;
  final List<WorkerTodayStats> workers;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (workers.isEmpty) {
      return OmEarthCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        showShadow: false,
        child: Center(
          child: Text(
            t.noWorkers,
            style: const TextStyle(
              color: ColorConstants.mutedText,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < workers.length; i++) ...[
          _WorkerMiniRow(
            t: t,
            stats: workers[i],
            onTap: () => onTap(workers[i].worker.id),
          ),
          if (i < workers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _WorkerMiniRow extends StatelessWidget {
  const _WorkerMiniRow({
    required this.t,
    required this.stats,
    required this.onTap,
  });

  final AppText t;
  final WorkerTodayStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = stats.treesToday > 0;

    return OmEarthCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 20,
      showShadow: true,
      child: Row(
        children: [
          OmEarthAvatar(
            initials: stats.worker.initials,
            size: 46,
            backgroundColor: ColorConstants.veryPaleGreen,
            foregroundColor: ColorConstants.forestGreen,
            showOnlineDot: isActive,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.worker.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? t.activeToday : t.notActiveToday,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? ColorConstants.successColor
                        : ColorConstants.mutedText,
                  ),
                ),
                if (stats.assignedPlotCount > 0)
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: ColorConstants.secondaryGreen,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          stats.assignedPlotSummary ?? '',
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                ImageConstants.leafSprig,
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text(
                '${stats.treesToday}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? ColorConstants.forestGreen
                      : ColorConstants.mutedText,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorConstants.mutedText,
              ),
            ],
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
              t.noPlots,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorConstants.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.noPlotsHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ColorConstants.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final preview = plots.take(3).toList();
    return Column(
      children: [
        for (int i = 0; i < preview.length; i++) ...[
          _PlotMiniRow(
            t: t,
            plot: preview[i],
            onTap: () => onTapPlot(preview[i]),
          ),
          if (i < preview.length - 1) const SizedBox(height: 10),
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
