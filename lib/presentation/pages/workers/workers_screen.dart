import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';
import 'package:mess_app/presentation/blocs/workers/workers_state.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

import 'add_worker_screen.dart';
import 'worker_detail_screen.dart';

/// Full field volunteers list — search, per-volunteer today activity, add volunteer.
class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key});

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
              children: [
                _WorkersAppBar(t: t),
                _SearchBar(t: t),
                const Expanded(child: _WorkersList()),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: Padding(
            padding: EdgeInsets.only(
              bottom: omEarthFabBottomOffset(context),
            ),
            child: FloatingActionButton(
              backgroundColor: ColorConstants.forestGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () => _openAddWorker(context, t),
              child: const Icon(Icons.person_add_rounded, size: 26),
            ),
          ),
        );
      },
    );
  }

  void _openAddWorker(BuildContext context, AppText t) async {
    final cubit = context.read<WorkersCubit>();
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddWorkerScreen(t: t, cubit: cubit)),
    );
    if (added == true && context.mounted) {
      cubit.load();
    }
  }
}

Future<void> _openEditWorker(
  BuildContext context,
  AppText t,
  WorkerModel worker,
) async {
  final cubit = context.read<WorkersCubit>();
  final updated = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => AddWorkerScreen(t: t, cubit: cubit, worker: worker),
    ),
  );
  if (updated == true && context.mounted) {
    cubit.load();
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _WorkersAppBar extends StatelessWidget {
  const _WorkersAppBar({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text(
            t.workers,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ColorConstants.lightTextPrimary,
            ),
          ),
          const SizedBox(width: 10),
          BlocBuilder<WorkersCubit, WorkersState>(
            builder: (context, state) {
              if (state is! WorkersLoaded) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorConstants.softGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.totalCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.forestGreen,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          BlocBuilder<WorkersCubit, WorkersState>(
            builder: (context, state) {
              if (state is! WorkersLoaded || state.activeToday == 0) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorConstants.successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: ColorConstants.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      t.activeCount(state.activeToday),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ColorConstants.successColor,
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

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.t});
  final AppText t;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: ColorConstants.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorConstants.borderGrey),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: ColorConstants.lightTextSecondary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.t.searchWorkers,
                  hintStyle: const TextStyle(
                    color: ColorConstants.lightTextSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => context.read<WorkersCubit>().search(v),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: ColorConstants.lightTextSecondary,
                ),
                onPressed: () {
                  _controller.clear();
                  context.read<WorkersCubit>().clearSearch();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Workers list ──────────────────────────────────────────────────────────────

class _WorkersList extends StatelessWidget {
  const _WorkersList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkersCubit, WorkersState>(
      builder: (context, state) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.language,
          builder: (context, lang, _) {
            final t = AppText(lang);

            if (state is WorkersLoading || state is WorkersInitial) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColorConstants.forestGreen,
                  ),
                ),
              );
            }

            if (state is WorkersError) {
              return Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: ColorConstants.errorColor),
                ),
              );
            }

            if (state is WorkersLoaded) {
              final items = state.filtered;
              if (items.isEmpty) {
                return _EmptyWorkers(t: t);
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  omEarthBottomScrollPadding(context),
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _WorkerCard(
                  t: t,
                  stats: items[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerDetailScreen(
                        workerId: items[i].worker.id,
                        t: t,
                      ),
                    ),
                  ),
                  onEdit: () => _openEditWorker(context, t, items[i].worker),
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

class _EmptyWorkers extends StatelessWidget {
  const _EmptyWorkers({required this.t});
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
                Icons.people_outline_rounded,
                size: 40,
                color: ColorConstants.forestGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t.noWorkers,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorConstants.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.noWorkersHint,
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

// ── Worker card ───────────────────────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.t,
    required this.stats,
    required this.onTap,
    required this.onEdit,
  });

  final AppText t;
  final WorkerTodayStats stats;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  Color get _avatarColor {
    if (!stats.worker.isActive) return ColorConstants.lightTextSecondary;
    if (stats.treesToday > 0) return ColorConstants.forestGreen;
    return ColorConstants.warningColor;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorConstants.lightCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorConstants.borderGrey),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _avatarColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  stats.worker.initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _avatarColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            stats.worker.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ColorConstants.lightTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!stats.worker.isActive)
                          _SmallChip(
                            label: t.inactive,
                            color: ColorConstants.lightTextSecondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stats.worker.phone ?? '—',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                    if (stats.assignedPlotCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        stats.assignedPlotSummary ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: ColorConstants.forestGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: t.edit,
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: ColorConstants.forestGreen,
                ),
              ),
              const SizedBox(width: 4),
              // Today count
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stats.treesToday}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: stats.treesToday > 0
                          ? ColorConstants.forestGreen
                          : ColorConstants.lightTextSecondary,
                    ),
                  ),
                  Text(
                    t.treesToday,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
