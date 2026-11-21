import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_cubit.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';
import 'package:mess_app/presentation/blocs/workers/workers_state.dart';
import 'package:mess_app/presentation/pages/worker/task_update_screen.dart';
import 'package:mess_app/presentation/pages/worker/worker_tree_detail_screen.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

/// Full detail view for an admin-assigned planting task.
/// Displays the target location, species, plot, admin notes, and lets the
/// field admin assign a field volunteer or plant the tree themselves.
class TreeTaskDetailScreen extends StatefulWidget {
  const TreeTaskDetailScreen({super.key, required this.task, required this.t});

  final TreeTaskModel task;
  final AppText t;

  @override
  State<TreeTaskDetailScreen> createState() => _TreeTaskDetailScreenState();
}

class _TreeTaskDetailScreenState extends State<TreeTaskDetailScreen> {
  late TreeTaskModel _task;
  UserSession? _session;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await getIt<SessionManager>().getSession();
    if (mounted && session?.role.isAdminVolunteer == true) {
      setState(() => _session = session);
    }
  }

  Future<void> _openPlantingForm(UserSession session) async {
    final tasksCubit = context.read<TreeTasksCubit>();
    final dashboardCubit = context.read<DashboardCubit>();
    setState(() => _claiming = true);
    try {
      final claimed = await tasksCubit.claimForSelf(_task.id);
      if (!mounted) return;
      setState(() => _task = claimed);
      if (!claimed.isSelfAssignedTo(session.userId) ||
          claimed.taskStatus != TaskStatus.assigned) {
        return;
      }
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TaskUpdateScreen(task: claimed, session: session),
        ),
      );
      if (!mounted) return;
      if (saved == true) {
        final updated = await getIt<TreeTaskRepository>().getById(claimed.id);
        if (mounted && updated != null) setState(() => _task = updated);
        await tasksCubit.load();
      }
      await dashboardCubit.refresh();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context: context,
          message: FieldApiService.messageOf(e),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _openPlantedTree(UserSession session) async {
    final task = _task;
    final treeId = task.treeId ?? task.id;
    final cached = await getIt<TreeRepository>().getById(treeId);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerTreeDetailScreen(
          tree:
              cached ??
              TreeModel(
                id: treeId,
                species: task.species,
                plotId: task.plotId,
                plotName: task.plotName,
                regionName: task.regionName,
                plantedBy: session.userName,
                plantedById: session.userId,
                plantingDate: task.updatedAt,
                latitude: task.latitude,
                longitude: task.longitude,
                notes: task.notes,
                createdAt: task.createdAt,
                updatedAt: task.updatedAt,
              ),
          workerId: session.userId,
          syncGrowth: task.treeId != null,
        ),
      ),
    );
  }

  Future<void> _copyLocation() async {
    await Clipboard.setData(ClipboardData(text: _task.locationLabel));
    if (mounted) {
      SnackbarHelper.showSucces(
        context: context,
        message: widget.t.locationCopied,
      );
    }
  }

  void _showAssignSheet() {
    final t = widget.t;
    final tasksCubit = context.read<TreeTasksCubit>();
    final workersCubit = context.read<WorkersCubit>();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: tasksCubit),
          BlocProvider.value(value: workersCubit),
        ],
        child: _AssignWorkerSheet(
          t: t,
          task: _task,
          onAssigned: (updated) {
            Navigator.pop(sheetCtx);
            if (mounted) {
              setState(() => _task = updated);
              SnackbarHelper.showSucces(
                context: context,
                message: t.workerAssigned,
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final task = _task;
    final session = _session;
    final isMine = session != null && task.isSelfAssignedTo(session.userId);
    final canPlant =
        session != null &&
        task.taskStatus.isActionable &&
        (task.workerId == null || task.workerId!.isEmpty) &&
        (task.volunteerId == null || task.volunteerId == session.userId);

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
          t.taskDetail,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
        actions: [
          _StatusPill(status: task.taskStatus, t: t),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Species / sponsor header ────────────────────────────────
          _SpeciesCard(task: task, t: t),
          const SizedBox(height: 16),

          // ── Sponsor intent ──────────────────────────────────────────
          _SectionCard(
            icon: Icons.volunteer_activism_outlined,
            iconColor: ColorConstants.primaryOrange,
            title: t.sponsorWantsPlanting,
            child: Text(
              task.displaySponsorIntent(t.sponsorIntentFor),
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: ColorConstants.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Tree / region / plot ────────────────────────────────────
          _SectionCard(
            icon: Icons.info_outline_rounded,
            iconColor: ColorConstants.infoColor,
            title: t.taskDetail,
            child: Column(
              children: [
                if (task.treeId != null && task.treeId!.isNotEmpty)
                  _DetailRow(label: t.treeIdLabel, value: task.treeId!),
                if (task.regionName != null && task.regionName!.isNotEmpty) ...[
                  if (task.treeId != null && task.treeId!.isNotEmpty)
                    const SizedBox(height: 12),
                  _DetailRow(label: t.regionLabel, value: task.regionName!),
                ],
                const SizedBox(height: 12),
                _DetailRow(label: t.plotLabel, value: task.displayPlotLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Target location ─────────────────────────────────────────
          _SectionCard(
            icon: Icons.location_on_rounded,
            iconColor: ColorConstants.primaryOrange,
            title: t.targetLocation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.locationLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.lightTextPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DetailRow(
                        label: 'Lat',
                        value: task.latitude.toStringAsFixed(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailRow(
                        label: 'Lon',
                        value: task.longitude.toStringAsFixed(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _copyLocation,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(t.targetLocation),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorConstants.primaryOrange,
                      side: const BorderSide(
                        color: ColorConstants.primaryOrange,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Target date ─────────────────────────────────────────────
          if (task.targetDate != null) ...[
            _SectionCard(
              icon: Icons.calendar_today_outlined,
              iconColor: ColorConstants.forestGreen,
              title: t.targetDate,
              child: Row(
                children: [
                  Text(
                    _formatDate(task.targetDate!),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.lightTextPrimary,
                    ),
                  ),
                  if (task.isDue && task.taskStatus.isActionable) ...[
                    const SizedBox(width: 10),
                    _DueBadge(t: t),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Admin notes (if different from sponsor intent) ──────────
          if (task.adminNotes != null &&
              task.adminNotes!.isNotEmpty &&
              task.adminNotes != task.sponsorIntent) ...[
            _SectionCard(
              icon: Icons.notes_rounded,
              iconColor: ColorConstants.lightTextSecondary,
              title: t.adminNotes,
              child: Text(
                task.adminNotes!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: ColorConstants.lightTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (task.isPlantingBatch) ...[
            Text(
              '${task.batchPlanted} of ${task.batchQuantity} trees planted',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.batchPlanted / task.batchQuantity,
            ),
            const SizedBox(height: 16),
          ],

          // ── Assignment ──────────────────────────────────────────────
          _AssignmentCard(task: task, t: t, isMine: isMine),
          const SizedBox(height: 24),
          if (canPlant) ...[
            PrimaryButton(
              label: isMine ? t.updateTask : t.plantMyself,
              icon: Icons.park_rounded,
              isLoading: _claiming,
              onPressed: () => _openPlantingForm(session),
            ),
            const SizedBox(height: 10),
          ],
          if (task.taskStatus.isActionable)
            OutlinedButton.icon(
              label: Text(task.workerId == null ? t.assignWorker : t.reassign),
              icon: const Icon(Icons.person_add_rounded),
              onPressed: _claiming ? null : _showAssignSheet,
            )
          else if (session != null &&
              isMine &&
              !task.isPlantingBatch &&
              task.taskStatus == TaskStatus.planted)
            PrimaryButton(
              label: t.treeDetails,
              icon: Icons.park_rounded,
              onPressed: () => _openPlantedTree(session),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Species card ──────────────────────────────────────────────────────────────

class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({required this.task, required this.t});
  final TreeTaskModel task;
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorConstants.forestGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.park_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.species,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.treeId != null && task.treeId!.isNotEmpty
                      ? '${t.treeIdLabel}: ${task.treeId}'
                      : task.id,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (task.regionName != null && task.regionName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.regionName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65),
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

// ── Section card wrapper ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.lightTextSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ColorConstants.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ColorConstants.warningColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        t.dueLabel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColorConstants.warningColor,
        ),
      ),
    );
  }
}

// ── Assignment card ───────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.task,
    required this.t,
    required this.isMine,
  });

  final TreeTaskModel task;
  final AppText t;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.people_rounded,
      iconColor: ColorConstants.infoColor,
      title: t.assignedTo,
      child: isMine
          ? Text(t.assignedToMe)
          : task.workerId == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      size: 20,
                      color: ColorConstants.lightTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t.unassigned,
                        style: const TextStyle(
                          fontSize: 14,
                          color: ColorConstants.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.taskStatus.isActionable) const SizedBox(height: 8),
                if (task.taskStatus.isActionable)
                  Text(
                    t.assignWorkerHint,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorConstants.infoColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: ColorConstants.infoColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.displayWorkerLabel.isNotEmpty
                        ? task.displayWorkerLabel
                        : task.workerId!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.t});
  final TaskStatus status;
  final AppText t;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaskStatus.pending => (t.unassigned, ColorConstants.warningColor),
      TaskStatus.assigned => (t.assigned, ColorConstants.infoColor),
      TaskStatus.planted => (t.planted, ColorConstants.successColor),
      TaskStatus.cancelled => ('Cancelled', ColorConstants.lightTextSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Assign worker bottom sheet ────────────────────────────────────────────────

class _AssignWorkerSheet extends StatelessWidget {
  const _AssignWorkerSheet({
    required this.t,
    required this.task,
    required this.onAssigned,
  });

  final AppText t;
  final TreeTaskModel task;
  final ValueChanged<TreeTaskModel> onAssigned;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ColorConstants.lightBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ColorConstants.borderGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  t.selectWorker,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<WorkersCubit, WorkersState>(
            builder: (context, state) {
              if (state is WorkersLoading || state is WorkersInitial) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ColorConstants.forestGreen,
                    ),
                  ),
                );
              }

              if (state is WorkersLoaded) {
                final workers = state.workers;
                if (workers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      t.noWorkers,
                      style: const TextStyle(
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: workers.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 60,
                      color: ColorConstants.borderGrey,
                    ),
                    itemBuilder: (ctx, i) => _WorkerSheetRow(
                      stats: workers[i],
                      isCurrentlyAssigned:
                          task.workerId == workers[i].worker.id,
                      t: t,
                      onTap: () async {
                        final tasksCubit = context.read<TreeTasksCubit>();
                        try {
                          final updated = await tasksCubit.assignWorker(
                            task.id,
                            workers[i].worker.id,
                            workerName: workers[i].worker.name,
                          );
                          if (context.mounted && updated != null) {
                            onAssigned(updated);
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          SnackbarHelper.showError(
                            context: context,
                            message: FieldApiService.messageOf(e),
                          );
                        }
                      },
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class _WorkerSheetRow extends StatelessWidget {
  const _WorkerSheetRow({
    required this.stats,
    required this.isCurrentlyAssigned,
    required this.t,
    required this.onTap,
  });

  final WorkerTodayStats stats;
  final bool isCurrentlyAssigned;
  final AppText t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worker = stats.worker;
    final avatarColor = stats.treesToday > 0
        ? ColorConstants.forestGreen
        : ColorConstants.warningColor;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: avatarColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          worker.initials,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: avatarColor,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            worker.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ColorConstants.lightTextPrimary,
            ),
          ),
          if (isCurrentlyAssigned) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ColorConstants.infoColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                t.assigned,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.infoColor,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        stats.treesToday > 0
            ? '${stats.treesToday} ${t.treesToday}'
            : t.notActiveToday,
        style: TextStyle(
          fontSize: 12,
          color: stats.treesToday > 0
              ? ColorConstants.successColor
              : ColorConstants.lightTextSecondary,
        ),
      ),
      trailing: isCurrentlyAssigned
          ? const Icon(
              Icons.check_circle_rounded,
              color: ColorConstants.infoColor,
            )
          : const Icon(
              Icons.chevron_right_rounded,
              color: ColorConstants.lightTextSecondary,
            ),
    );
  }
}
