import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_cubit.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_state.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

import 'tree_task_detail_screen.dart';
import 'corporate_plantation_screen.dart';

/// Full task list — filter tabs (All / Unassigned / Assigned / Planted) and
/// cards showing each admin-assigned planting task.
class TreeTasksScreen extends StatefulWidget {
  const TreeTasksScreen({super.key});

  @override
  State<TreeTasksScreen> createState() => _TreeTasksScreenState();
}

class _TreeTasksScreenState extends State<TreeTasksScreen> {
  Map<String, String> _filters = const {};

  Map<String, String> _taskValues(TreeTaskModel task) => {
    'Sponsorship': task.programName?.isNotEmpty == true
        ? 'Corporate (legacy)'
        : task.sponsorshipId?.isNotEmpty == true
        ? 'Individual'
        : 'Other field work',
    'Region': task.regionName ?? '',
    'Plot': task.plotName ?? task.plotId,
    'Volunteer': task.workerName ?? '',
  };

  bool _matches(TreeTaskModel task) {
    final values = _taskValues(task);
    return _filters.entries.every(
      (filter) => values[filter.key] == filter.value,
    );
  }

  Future<void> _openFilters() async {
    final current = context.read<TreeTasksCubit>().state;
    if (current is! TreeTasksLoaded) return;
    final options = <String, Set<String>>{
      'Sponsorship': {'Individual', 'Corporate (legacy)', 'Other field work'},
      'Region': {},
      'Plot': {},
      'Volunteer': {},
    };
    for (final task in current.tasks) {
      for (final entry in _taskValues(task).entries) {
        if (entry.value.isNotEmpty) options[entry.key]!.add(entry.value);
      }
    }
    final draft = Map<String, String>.from(_filters);
    final applied = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, redraw) {
          return AlertDialog(
            title: const Text('Filter planting tasks'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in options.entries)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: entry.value.contains(draft[entry.key])
                          ? draft[entry.key]
                          : '',
                      decoration: InputDecoration(labelText: entry.key),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All')),
                        for (final value in entry.value.toList()..sort())
                          DropdownMenuItem(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => redraw(() {
                        if (value?.isNotEmpty == true) {
                          draft[entry.key] = value!;
                        } else {
                          draft.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, <String, String>{}),
                child: const Text('Clear filters'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, draft),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    if (applied != null && mounted) setState(() => _filters = applied);
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
                _TasksAppBar(t: t),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.forest_outlined),
                        label: Text(
                          lang == AppLanguage.malayalam
                              ? 'കോർപ്പറേറ്റ് നടീൽ ബാച്ചുകൾ'
                              : 'Corporate planting batches',
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CorporatePlantationScreen(),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.filter_list),
                        label: Text(
                          _filters.isEmpty
                              ? 'Filter tasks'
                              : 'Filters (${_filters.length})',
                        ),
                      ),
                    ],
                  ),
                ),
                _FilterTabs(t: t),
                Expanded(child: _TaskList(matches: _matches)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _TasksAppBar extends StatelessWidget {
  const _TasksAppBar({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            t.tasks,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ColorConstants.lightTextPrimary,
            ),
          ),
          const SizedBox(width: 10),
          BlocBuilder<TreeTasksCubit, TreeTasksState>(
            builder: (context, state) {
              if (state is! TreeTasksLoaded) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ColorConstants.softGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.tasksCount(state.tasks.length),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.forestGreen,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          BlocBuilder<TreeTasksCubit, TreeTasksState>(
            builder: (context, state) {
              if (state is! TreeTasksLoaded || state.pendingCount == 0) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ColorConstants.warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions_rounded,
                      size: 14,
                      color: ColorConstants.warningColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${state.pendingCount} ${t.unassigned}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ColorConstants.warningColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Filter tabs ───────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TreeTasksCubit, TreeTasksState>(
      builder: (context, state) {
        final active = state is TreeTasksLoaded ? state.activeFilter : null;
        final cubit = context.read<TreeTasksCubit>();

        final tabs = <(TaskStatus?, String)>[
          (null, t.allTasks),
          (TaskStatus.pending, t.unassigned),
          (TaskStatus.assigned, t.assigned),
          (TaskStatus.planted, t.planted),
        ];

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (status, label) = tabs[i];
              final selected = active == status;
              return GestureDetector(
                onTap: () => cubit.setFilter(status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected
                        ? ColorConstants.forestGreen
                        : ColorConstants.lightCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? ColorConstants.forestGreen
                          : ColorConstants.borderGrey,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : ColorConstants.lightTextPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Task list ─────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  const _TaskList({required this.matches});

  final bool Function(TreeTaskModel) matches;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TreeTasksCubit, TreeTasksState>(
      builder: (context, state) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.language,
          builder: (context, lang, _) {
            final t = AppText(lang);

            if (state is TreeTasksLoading || state is TreeTasksInitial) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColorConstants.forestGreen,
                  ),
                ),
              );
            }

            if (state is TreeTasksError) {
              return Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: ColorConstants.errorColor),
                ),
              );
            }

            if (state is TreeTasksLoaded) {
              final items = state.filtered.where(matches).toList();
              if (items.isEmpty) return _EmptyTasks(t: t);
              return RefreshIndicator(
                color: ColorConstants.forestGreen,
                onRefresh: () => context.read<TreeTasksCubit>().syncAndLoad(),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    omEarthBottomScrollPadding(context),
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final cubit = context.read<TreeTasksCubit>();
                    return _TaskCard(
                      t: t,
                      task: items[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TreeTaskDetailScreen(task: items[i], t: t),
                        ),
                      ).then((_) => cubit.load()),
                    );
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ColorConstants.softGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 40,
                color: ColorConstants.forestGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t.noTasksYet,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorConstants.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.noTasksHint,
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

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.t, required this.task, required this.onTap});

  final AppText t;
  final TreeTaskModel task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorConstants.lightCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: task.isDue && task.taskStatus.isActionable
                  ? ColorConstants.warningColor.withValues(alpha: 0.4)
                  : ColorConstants.borderGrey,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Species icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _statusColor(
                        task.taskStatus,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.park_rounded,
                      size: 22,
                      color: _statusColor(task.taskStatus),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.species,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ColorConstants.lightTextPrimary,
                          ),
                        ),
                        Text(
                          task.displaySponsorIntent(t.sponsorIntentFor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: ColorConstants.lightTextSecondary,
                          ),
                        ),
                        if (task.regionName != null &&
                            task.regionName!.isNotEmpty)
                          Text(
                            '${t.regionLabel}: ${task.regionName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ColorConstants.forestGreen,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: task.taskStatus, t: t),
                ],
              ),
              const SizedBox(height: 10),
              // Meta row: tree id / plot (+ needs-assignment / due chip)
              Row(
                children: [
                  if (task.treeId != null && task.treeId!.isNotEmpty) ...[
                    const Icon(
                      Icons.tag_rounded,
                      size: 14,
                      color: ColorConstants.lightTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        task.displayTreeIdShort,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ColorConstants.lightTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(
                    Icons.map_outlined,
                    size: 14,
                    color: ColorConstants.lightTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      task.displayPlotLabel,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                  ),
                  if (task.needsAssignment) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ColorConstants.primaryOrange.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        t.needsPlanting,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ColorConstants.primaryOrange,
                        ),
                      ),
                    ),
                  ] else if (task.isDue && task.taskStatus.isActionable) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ColorConstants.warningColor.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        t.dueLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ColorConstants.warningColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Assignment info
              if (task.taskStatus == TaskStatus.assigned &&
                  task.workerId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: ColorConstants.infoColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${t.assignedTo}: ${task.displayWorkerLabel}',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ColorConstants.infoColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (task.taskStatus == TaskStatus.pending) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(t.taskDetails),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorConstants.forestGreen,
                      side: const BorderSide(color: ColorConstants.forestGreen),
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
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(TaskStatus status) {
    return switch (status) {
      TaskStatus.pending => ColorConstants.warningColor,
      TaskStatus.assigned => ColorConstants.infoColor,
      TaskStatus.planted => ColorConstants.successColor,
      TaskStatus.cancelled => ColorConstants.lightTextSecondary,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.t});
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
