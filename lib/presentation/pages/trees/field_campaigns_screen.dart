import 'package:flutter/material.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/presentation/pages/tasks/corporate_plantation_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';
import 'package:mess_app/presentation/widgets/planted_tree_tile.dart';

typedef _Row = Map<String, dynamic>;

int _count(_Row row, String key) => (row[key] as num?)?.toInt() ?? 0;
String _text(_Row row, String key) => row[key]?.toString() ?? '';

String _site(_Row row) => [
  _text(row, 'region'),
  _text(row, 'plot'),
].where((name) => name.isNotEmpty).join(' · ');

class FieldCampaignsScreen extends StatelessWidget {
  const FieldCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Corporate campaigns')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: FieldCampaignsPanel(),
    ),
  );
}

/// Campaigns and site summaries are loaded without individual tree records.
class FieldCampaignsPanel extends StatefulWidget {
  const FieldCampaignsPanel({super.key});

  @override
  State<FieldCampaignsPanel> createState() => _FieldCampaignsPanelState();
}

class _FieldCampaignsPanelState extends State<FieldCampaignsPanel> {
  late Future<List<_Row>> _allocations = getIt<FieldApiService>()
      .listPlantationAllocations();
  String _search = '';

  void _refresh() => setState(() {
    _allocations = getIt<FieldApiService>().listPlantationAllocations();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_Row>>(
    future: _allocations,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(FieldApiService.messageOf(snapshot.error!)),
            TextButton(
              onPressed: _refresh,
              child: const Text('Retry campaigns'),
            ),
          ],
        );
      }
      final campaigns = <String, List<_Row>>{};
      for (final allocation in snapshot.data ?? <_Row>[]) {
        (campaigns[_text(allocation, 'programId')] ??= []).add(allocation);
      }
      if (campaigns.isEmpty) {
        return const Text(
          'No corporate campaigns in your assignments or plots.',
        );
      }
      final matches = campaigns.values.where((sites) {
        final first = sites.first;
        final names = '${first['companyName']} ${first['programName']}'
            .toLowerCase();
        return names.contains(_search.trim().toLowerCase());
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search campaigns',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty) const Text('No campaigns match this search.'),
          for (final sites in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OmEarthCard(
                padding: const EdgeInsets.all(12),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    title: Text(_text(sites.first, 'programName')),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_text(sites.first, 'companyName')),
                        _CampaignProgress(campaign: sites.first),
                        Text(
                          sites.map(_site).toSet().join(' / '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _CampaignDetail(
                            id: _text(sites.first, 'programId'),
                            title: _text(sites.first, 'programName'),
                          ),
                        ),
                      );
                      if (mounted) _refresh();
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CampaignProgress extends StatelessWidget {
  const _CampaignProgress({required this.campaign});
  final _Row campaign;

  @override
  Widget build(BuildContext context) {
    final target = _count(campaign, 'sponsored');
    final planted = _count(campaign, 'campaignPlanted');
    final ratio = target == 0 ? 0.0 : (planted / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$planted of $target planted · ${(target - planted).clamp(0, target)} remaining · ${(ratio * 100).round()}%',
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ratio,
            color: ColorConstants.forestGreen,
          ),
        ],
      ),
    );
  }
}

class _CampaignDetail extends StatefulWidget {
  const _CampaignDetail({required this.id, required this.title});
  final String id;
  final String title;

  @override
  State<_CampaignDetail> createState() => _CampaignDetailState();
}

class _CampaignDetailState extends State<_CampaignDetail> {
  final _api = getIt<FieldApiService>();
  late Future<(List<_Row>, List<_Row>)> _data = _load();
  String? _region;
  String? _plot;
  String? _volunteer;
  String? _status;

  Future<(List<_Row>, List<_Row>)> _load() async {
    final results = await Future.wait([
      _api.listPlantationAllocations(),
      _api.listPlantationBatches(),
    ]);
    return (
      results[0].where((row) => row['programId'] == widget.id).toList(),
      results[1].where((row) => row['programId'] == widget.id).toList(),
    );
  }

  void _refresh() => setState(() => _data = _load());

  Future<void> _editAllocation(_Row? allocation) async {
    try {
      final options = <String, String>{};
      final species = <String, String>{};
      if (allocation != null) {
        options[_text(allocation, 'plotId')] = _site(allocation);
        species[_text(allocation, 'speciesId')] = _text(allocation, 'species');
      } else {
        final plots = await getIt<PlotRepository>().getAssignedPlots();
        final catalog = await _api.listPlantationSpecies();
        for (final plot in plots) {
          options[plot.serverId ?? plot.id] = plot.name;
        }
        for (final item in catalog) {
          species[_text(item, 'id')] = _text(item, 'commonName');
        }
      }
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _QuantityDialog(
          title: allocation != null ? 'Adjust allocation' : 'Add allocation',
          min: allocation != null
              ? _count(allocation, 'assigned').clamp(1, 100000)
              : 1,
          initial: allocation == null ? null : _count(allocation, 'quantity'),
          choices: {'Plot': options, 'Species': species},
          fixedChoices: allocation != null,
          onSave: (quantity, picks, _) =>
              _api.savePlantationAllocation(widget.id, {
                if (allocation != null) 'allocationId': allocation['id'],
                'plotId': picks['Plot'],
                'speciesId': picks['Species'],
                'quantity': quantity,
              }),
        ),
      );
      if (saved == true && mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FieldApiService.messageOf(error))),
        );
      }
    }
  }

  Future<void> _createBatch(_Row allocation) async {
    try {
      final workers = await _api.listWorkers();
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _QuantityDialog(
          title: 'Assign planting batch',
          max: _count(allocation, 'quantity') - _count(allocation, 'assigned'),
          choices: {
            'Volunteer': {
              '': 'Field admin (self)',
              for (final raw in workers.whereType<_Row>())
                if (raw['isActive'] == true &&
                    (raw['plotIds'] as List?)?.contains(allocation['plotId']) ==
                        true)
                  _text(raw, 'id'): _text(raw, 'name'),
            },
          },
          deadline: true,
          onSave: (quantity, picks, date) =>
              _api.createPlantationBatch(widget.id, {
                'allocationId': allocation['id'],
                'quantity': quantity,
                'workerId': picks['Volunteer'],
                'targetDate': date,
              }),
        ),
      );
      if (saved == true && mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FieldApiService.messageOf(error))),
        );
      }
    }
  }

  Future<void> _editBatch(_Row allocation, _Row batch) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _QuantityDialog(
        title: 'Adjust planting batch',
        choices: const {},
        min: _count(batch, 'planted').clamp(1, 100000),
        max:
            _count(allocation, 'quantity') -
            _count(allocation, 'assigned') +
            _count(batch, 'quantity'),
        initial: _count(batch, 'quantity'),
        initialDeadline: _text(batch, 'targetDate'),
        deadline: true,
        onSave: (quantity, _, date) => _api.updatePlantationBatch(
          _text(batch, 'id'),
          quantity: quantity,
          targetDate: date,
        ),
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  String _batchStatus(_Row batch) {
    if (_count(batch, 'planted') >= _count(batch, 'quantity')) {
      return 'Completed';
    }
    if (batch['canRecord'] != true) return 'Closed';
    return _count(batch, 'planted') > 0 ? 'In progress' : 'Assigned';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh campaign',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<(List<_Row>, List<_Row>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(FieldApiService.messageOf(snapshot.error!)),
          );
        }
        final (allocations, batches) = snapshot.data!;
        if (allocations.isEmpty) {
          return const Center(child: Text('No accessible allocations.'));
        }
        final campaign = allocations.first;
        final managed = allocations.any((row) => row['canManage'] == true);
        final visible = allocations.where(
          (row) =>
              (_region == null || row['region'] == _region) &&
              (_plot == null || row['plot'] == _plot),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _text(campaign, 'companyName'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Campaign ${widget.id}'),
            _CampaignProgress(campaign: campaign),
            Text(
              '${_count(campaign, 'campaignAllocated')} allocated across the campaign',
            ),
            if (managed &&
                _count(campaign, 'campaignAllocated') <
                    _count(campaign, 'sponsored'))
              OutlinedButton.icon(
                onPressed: () => _editAllocation(null),
                icon: const Icon(Icons.add),
                label: const Text('Add allocation'),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                _filter(
                  'Region',
                  _region,
                  allocations.map((row) => _text(row, 'region')),
                  (value) => setState(() => _region = value),
                ),
                _filter(
                  'Plot',
                  _plot,
                  allocations.map((row) => _text(row, 'plot')),
                  (value) => setState(() => _plot = value),
                ),
                _filter(
                  'Volunteer',
                  _volunteer,
                  batches.map(_planter),
                  (value) => setState(() => _volunteer = value),
                ),
                _filter('Batch status', _status, [
                  'Assigned',
                  'In progress',
                  'Completed',
                  'Closed',
                  'Unassigned quantity',
                ], (value) => setState(() => _status = value)),
              ],
            ),
            const SizedBox(height: 10),
            for (final row in visible)
              _allocationTile(
                row,
                batches
                    .where((batch) => batch['allocationId'] == row['id'])
                    .toList(),
              ),
          ],
        );
      },
    ),
  );

  String _planter(_Row batch) => _text(batch, 'volunteer').isEmpty
      ? _text(batch, 'fieldAdmin')
      : _text(batch, 'volunteer');

  Widget _filter(
    String label,
    String? value,
    Iterable<String> choices,
    ValueChanged<String?> onChanged,
  ) {
    final values = choices.where((name) => name.isNotEmpty).toSet();
    return DropdownButton<String>(
      value: values.contains(value) ? value : '',
      items: [
        DropdownMenuItem(value: '', child: Text(label)),
        for (final name in values)
          DropdownMenuItem(value: name, child: Text(name)),
      ],
      onChanged: (selected) =>
          onChanged(selected?.isEmpty == true ? null : selected),
    );
  }

  Widget _allocationTile(_Row row, List<_Row> batches) {
    final remaining = _count(row, 'quantity') - _count(row, 'assigned');
    final visible = batches
        .where(
          (batch) =>
              (_volunteer == null || _planter(batch) == _volunteer) &&
              (_status == null || _batchStatus(batch) == _status),
        )
        .toList();
    if (_status == 'Unassigned quantity' && remaining <= 0) {
      return const SizedBox.shrink();
    }
    if ((_volunteer != null ||
            (_status != null && _status != 'Unassigned quantity')) &&
        visible.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ExpansionTile(
        key: PageStorageKey(row['id']),
        title: Text(_site(row)),
        subtitle: Text(
          "${row['species']} · ${row['planted']} / ${row['quantity']} planted",
        ),
        children: [
          if (row['legacy'] != true)
            ListTile(
              title: Text('$remaining trees left to assign'),
              subtitle: _text(row, 'lastPlanting').isEmpty
                  ? null
                  : Text("Latest planting · ${row['lastPlanting']}"),
            )
          else
            const ListTile(
              title: Text(
                'This campaign uses existing individual planting tasks.',
              ),
            ),
          for (final batch in visible)
            ListTile(
              title: Text(_planter(batch)),
              subtitle: Text(
                "${_batchStatus(batch)} · ${batch['planted']} / ${batch['quantity']} planted"
                "${_text(batch, 'targetDate').isEmpty ? '' : ' · Due ${batch['targetDate']}'}",
              ),
              trailing: row['canManage'] == true && batch['canRecord'] == true
                  ? IconButton(
                      tooltip: 'Adjust batch quantity or deadline',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editBatch(row, batch),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _BatchTreesScreen(batch: batch),
                ),
              ),
            ),
          Wrap(
            spacing: 6,
            children: [
              if (row['canManage'] == true)
                TextButton(
                  onPressed: () => _editAllocation(row),
                  child: const Text('Adjust allocation'),
                ),
              if (row['canManage'] == true && remaining > 0)
                TextButton(
                  onPressed: () => _createBatch(row),
                  child: const Text('Assign batch'),
                ),
              if (batches.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CorporatePlantationScreen(
                          allocationId: _text(row, 'id'),
                        ),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                  child: const Text('Tasks, sessions and photos'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatchTreesScreen extends StatefulWidget {
  const _BatchTreesScreen({required this.batch});
  final _Row batch;

  @override
  State<_BatchTreesScreen> createState() => _BatchTreesScreenState();
}

class _BatchTreesScreenState extends State<_BatchTreesScreen> {
  int _page = 1;
  late Future<_Row> _trees = _load();
  Future<_Row> _load() =>
      getIt<FieldApiService>().batchTrees(_text(widget.batch, 'id'), _page);

  void _go(int page) => setState(() {
    _page = page;
    _trees = _load();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Batch trees')),
    body: FutureBuilder<_Row>(
      future: _trees,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(FieldApiService.messageOf(snapshot.error!)),
          );
        }
        final data = snapshot.data!;
        final pageSize = _count(data, 'pageSize');
        final rows = (data['trees'] as List).cast<_Row>();
        final language = AppText(LanguageController.language.value);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _site(widget.batch),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (rows.isEmpty) const Text('No planted trees in this batch yet.'),
            for (final row in rows)
              PlantedTreeTile(tree: TreeModel.fromFieldApi(row), t: language),
            if (_count(data, 'total') > pageSize)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _page > 1 ? () => _go(_page - 1) : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page $_page'),
                  TextButton(
                    onPressed: _page * pageSize < _count(data, 'total')
                        ? () => _go(_page + 1)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.title,
    required this.choices,
    required this.onSave,
    this.fixedChoices = false,
    this.deadline = false,
    this.initialDeadline = '',
    this.initial,
    this.min = 1,
    this.max = 100000,
  });
  final String title;
  final Map<String, Map<String, String>> choices;
  final Future<void> Function(
    int quantity,
    Map<String, String> picks,
    String date,
  )
  onSave;
  final bool fixedChoices;
  final bool deadline;
  final String initialDeadline;
  final int? initial;
  final int min;
  final int max;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _form = GlobalKey<FormState>();
  final _picks = <String, String>{};
  late final _quantity = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  late String _date = widget.initialDeadline;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final entry in widget.choices.entries) {
      if (entry.value.length == 1 || entry.value.containsKey('')) {
        _picks[entry.key] = entry.value.keys.first;
      }
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(int.parse(_quantity.text), _picks, _date);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = FieldApiService.messageOf(error);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in widget.choices.entries)
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(labelText: entry.key),
                initialValue: _picks[entry.key],
                items: [
                  for (final choice in entry.value.entries)
                    DropdownMenuItem(
                      value: choice.key,
                      child: Text(
                        choice.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: widget.fixedChoices || _saving
                    ? null
                    : (value) {
                        if (value != null) _picks[entry.key] = value;
                      },
                validator: (_) => _picks.containsKey(entry.key)
                    ? null
                    : 'Choose ${entry.key.toLowerCase()}',
              ),
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tree quantity'),
              validator: (value) {
                final quantity = int.tryParse(value ?? '');
                return quantity == null ||
                        quantity < widget.min ||
                        quantity > widget.max
                    ? 'Enter ${widget.min}–${widget.max} trees'
                    : null;
              },
            ),
            if (widget.deadline)
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          firstDate: now,
                          initialDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (date != null && mounted) {
                          setState(
                            () =>
                                _date = date.toIso8601String().substring(0, 10),
                          );
                        }
                      },
                child: Text(_date.isEmpty ? 'Set deadline (optional)' : _date),
              ),
            if (widget.deadline && _date.isNotEmpty)
              TextButton(
                onPressed: _saving ? null : () => setState(() => _date = ''),
                child: const Text('Clear deadline'),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Save'),
      ),
    ],
  );
}
