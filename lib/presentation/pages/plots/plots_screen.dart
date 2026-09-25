import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:mess_app/presentation/pages/plots/plot_detail_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

/// Full plots list for volunteer admins — browse, search, view details.
/// Plot create/edit/end is staff-only via the web admin panel.
class PlotsScreen extends StatefulWidget {
  const PlotsScreen({super.key});

  @override
  State<PlotsScreen> createState() => _PlotsScreenState();
}

class _PlotsScreenState extends State<PlotsScreen> {
  String _query = '';

  void _openPlotDetail(AppText t, PlotModel plot) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PlotDetailScreen(plot: plot, t: t),
      ),
    );
  }

  List<PlotModel> _filtered(List<PlotModel> plots) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return plots;
    return plots.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.location.toLowerCase().contains(q) ||
          (p.district?.toLowerCase().contains(q) ?? false);
    }).toList();
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
              children: [
                _PlotsAppBar(t: t),
                _SearchBar(
                  t: t,
                  onChanged: (v) => setState(() => _query = v),
                ),
                Expanded(
                  child: BlocBuilder<DashboardCubit, DashboardState>(
                    builder: (context, state) {
                      if (state.isLoading && state.plots.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ColorConstants.forestGreen,
                            ),
                          ),
                        );
                      }

                      final items = _filtered(state.plots);
                      if (items.isEmpty) {
                        return _EmptyPlots(t: t);
                      }

                      return RefreshIndicator(
                        color: ColorConstants.forestGreen,
                        backgroundColor: ColorConstants.cardSurface,
                        onRefresh: () =>
                            context.read<DashboardCubit>().refresh(),
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            omEarthBottomScrollPadding(context),
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final plot = items[i];
                            return _PlotCard(
                              t: t,
                              plot: plot,
                              onTap: () => _openPlotDetail(t, plot),
                            );
                          },
                        ),
                      );
                    },
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

class _PlotsAppBar extends StatelessWidget {
  const _PlotsAppBar({required this.t});
  final AppText t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text(
            t.allPlots,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ColorConstants.lightTextPrimary,
            ),
          ),
          const SizedBox(width: 10),
          BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              if (state.plots.isEmpty) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorConstants.softGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.plots.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.forestGreen,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.t, required this.onChanged});
  final AppText t;
  final ValueChanged<String> onChanged;

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
                  hintText: widget.t.searchPlots,
                  hintStyle: const TextStyle(
                    color: ColorConstants.lightTextSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: widget.onChanged,
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
                  widget.onChanged('');
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlots extends StatelessWidget {
  const _EmptyPlots({required this.t});
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
              ImageConstants.seedling,
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              t.noPlots,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorConstants.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.noPlotsHint,
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

class _PlotCard extends StatelessWidget {
  const _PlotCard({
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

    return Material(
      color: ColorConstants.lightCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorConstants.borderGrey),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                      plot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plot.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                    if (plot.areaHectares != null || plot.treeCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (plot.treeCount > 0) t.treesCount(plot.treeCount),
                          if (plot.areaHectares != null)
                            '${plot.areaHectares!.toStringAsFixed(1)} ha',
                        ].join(' · '),
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
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OmEarthStatusChip(label: status.$1, color: status.$2),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: ColorConstants.mutedText,
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
