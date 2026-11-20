import 'package:flutter/material.dart';
import 'field_campaigns_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';
import 'package:mess_app/presentation/widgets/planted_tree_tile.dart';

class FieldTreesScreen extends StatefulWidget {
  const FieldTreesScreen({super.key, required this.active});

  final bool active;

  @override
  State<FieldTreesScreen> createState() => _FieldTreesScreenState();
}

class _FieldTreesScreenState extends State<FieldTreesScreen> {
  Future<List<TreeModel>>? _trees;
  String _category = 'all';
  int _campaignVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _trees = _readTrees();
  }

  @override
  void didUpdateWidget(covariant FieldTreesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _trees = _readTrees();
  }

  Future<List<TreeModel>> _readTrees() =>
      getIt<TreeRepository>().getFieldInventory();

  Future<void> _refresh() async {
    await context.read<DashboardCubit>().triggerSync();
    if (mounted) {
      setState(() {
        _trees = _readTrees();
        _campaignVersion++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardCubit, DashboardState>(
      listenWhen: (previous, current) =>
          widget.active &&
          previous.syncJobStatus != current.syncJobStatus &&
          current.syncJobStatus == SyncJobStatus.succeeded,
      listener: (_, _) => setState(() => _trees = _readTrees()),
      child: ValueListenableBuilder<AppLanguage>(
        valueListenable: LanguageController.language,
        builder: (context, language, _) {
          final t = AppText(language);
          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: ColorConstants.forestGreen,
              child: FutureBuilder<List<TreeModel>>(
                future: _trees,
                builder: (context, snapshot) {
                  final trees = snapshot.data
                      ?.where(
                        (tree) => switch (_category) {
                          'individual' =>
                            tree.sponsorshipCategory == 'individual',
                          'corporate' =>
                            tree.sponsorshipCategory == 'corporate',
                          _ => tree.sponsorshipCategory != 'corporate',
                        },
                      )
                      .toList();
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      omEarthBottomScrollPadding(context),
                    ),
                    children: [
                      OmEarthSectionHeader(
                        title: trees == null
                            ? t.plantedTrees
                            : '${t.plantedTrees} (${trees.length})',
                        showLeafIcon: true,
                        trailing: IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).refreshIndicatorSemanticLabel,
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final (value, label) in [
                            ('all', 'All'),
                            ('individual', 'Individual'),
                            ('corporate', 'Corporate'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _category == value,
                              onSelected: (_) =>
                                  setState(() => _category = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (widget.active && _category == 'corporate') ...[
                        FieldCampaignsPanel(key: ValueKey(_campaignVersion)),
                        if (trees?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Corporate trees from individual planting tasks',
                          ),
                        ],
                      ] else if (_category == 'all')
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _category = 'corporate'),
                            child: const Text('Browse corporate campaigns'),
                          ),
                        ),
                      if (snapshot.hasError)
                        Text(t.couldNotLoadPlantedTrees)
                      else if (trees == null)
                        const Center(child: CircularProgressIndicator())
                      else if (trees.isEmpty && _category != 'corporate')
                        Text(t.noTreesPlanted)
                      else if (_category == 'corporate')
                        ..._legacyCampaigns(t, trees)
                      else
                        ..._regionSections(t, trees),
                      if (widget.active && _category == 'all') ...[
                        const SizedBox(height: 14),
                        const OmEarthSectionHeader(
                          title: 'Corporate campaigns',
                        ),
                        const SizedBox(height: 8),
                        FieldCampaignsPanel(key: ValueKey(_campaignVersion)),
                      ],
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _legacyCampaigns(AppText t, List<TreeModel> trees) {
    final grouped = <String, List<TreeModel>>{};
    for (final tree in trees) {
      (grouped[tree.corporateProgramId ?? ''] ??= []).add(tree);
    }
    return [
      for (final group in grouped.entries)
        Card(
          child: ExpansionTile(
            title: Text(
              group.key.isEmpty
                  ? 'Earlier corporate plantings'
                  : 'Campaign ${group.key}',
            ),
            subtitle: Text('${group.value.length} planted trees'),
            children: _regionSections(t, group.value),
          ),
        ),
    ];
  }

  List<Widget> _regionSections(AppText t, List<TreeModel> trees) {
    final regions = <String, Map<String, List<TreeModel>>>{};
    for (final tree in trees) {
      final plots = regions[tree.regionName ?? t.regionUnassigned] ??= {};
      (plots[tree.plotId] ??= []).add(tree);
    }

    return [
      for (final region in regions.entries) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: OmEarthSectionHeader(title: region.key),
        ),
        for (final plot in region.value.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OmEarthCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plot.first.plotName ?? plot.first.plotId,
                    style: const TextStyle(
                      color: ColorConstants.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final tree in plot) PlantedTreeTile(tree: tree, t: t),
                ],
              ),
            ),
          ),
      ],
    ];
  }
}
