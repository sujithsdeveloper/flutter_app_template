import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/api_client.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/tree_growth_update_model.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/repositories/tree_growth_repository.dart';
import 'package:mess_app/presentation/pages/worker/growth_update_screen.dart';

/// Shows full details of a planted tree and its growth history.
/// The planter can add growth updates and a supervisor can review them.
class WorkerTreeDetailScreen extends StatefulWidget {
  const WorkerTreeDetailScreen({
    super.key,
    required this.tree,
    required this.workerId,
    this.readOnly = false,
    this.syncGrowth = false,
  });

  final TreeModel tree;
  final String workerId;

  /// Supervisors can view a field volunteer's tree without editing it.
  final bool readOnly;

  /// A self-planted tree linked to the server has shared growth history.
  final bool syncGrowth;

  @override
  State<WorkerTreeDetailScreen> createState() => _WorkerTreeDetailScreenState();
}

class _WorkerTreeDetailScreenState extends State<WorkerTreeDetailScreen> {
  List<TreeGrowthUpdateModel> _updates = [];
  bool _loading = true;
  Map<String, dynamic>? _details;

  final _repo = getIt<TreeGrowthRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final local = await _repo.getForTree(widget.tree.id);
    var updates = local;
    var details = _details;
    if (widget.syncGrowth) {
      final api = getIt<FieldApiService>();
      final id = widget.tree.serverId ?? widget.tree.id;
      try {
        details = await api.fieldTreeDetails(id);
      } catch (error) {
        AppLogger.error(
          '[WorkerTreeDetailScreen] tree details unavailable: $error',
        );
      }
      try {
        final remote = await api.listGrowthUpdates(id);
        final byId = {for (final update in local) update.id: update};
        for (final entry in remote) {
          final update = TreeGrowthUpdateModel.fromApi(entry);
          final localPhoto = byId[update.id]?.photoPath;
          byId[update.id] = update.photoPath == null && localPhoto != null
              ? TreeGrowthUpdateModel.fromApi({
                  ...entry,
                  'photoUrl': localPhoto,
                })
              : update;
        }
        updates = byId.values.toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      } catch (error) {
        AppLogger.error(
          '[WorkerTreeDetailScreen] growth history unavailable: $error',
        );
      }
    }
    if (mounted) {
      setState(() {
        _updates = updates;
        _details = details;
        _loading = false;
      });
    }
  }

  GrowthStage get _currentStage =>
      _updates.isEmpty ? GrowthStage.planted : _updates.first.stage;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, lang, _) {
        final t = AppText(lang);
        return Scaffold(
          backgroundColor: ColorConstants.lightBackgroundSecondary,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(t),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildInfoCard(t),
                      const SizedBox(height: 16),
                      _buildCurrentStageCard(t),
                      const SizedBox(height: 20),
                      _buildHistorySection(t),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton:
              (_details?['canUpdate'] == false ||
                  (_details?['canUpdate'] != true && widget.readOnly))
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: ColorConstants.forestGreen,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    t.addGrowthUpdate,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GrowthUpdateScreen(
                          treeId: widget.tree.serverId ?? widget.tree.id,
                          workerId: widget.workerId,
                          species: widget.tree.species,
                          requireServerSave: widget.syncGrowth,
                          cacheLocally:
                              widget.tree.sponsorshipCategory != 'corporate',
                        ),
                      ),
                    ).then((saved) {
                      if (saved == true) _load();
                    });
                  },
                ),
        );
      },
    );
  }

  Widget _buildAppBar(AppText t) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: ColorConstants.forestGreen,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Show latest photo or a gradient banner
            Builder(
              builder: (_) {
                final photoUpdate = _updates
                    .cast<TreeGrowthUpdateModel?>()
                    .firstWhere(
                      (u) => u?.photoPath != null,
                      orElse: () => null,
                    );
                final photoPath =
                    photoUpdate?.photoPath ??
                    _details?['initialPhoto'] as String?;
                if (photoPath?.isNotEmpty == true) {
                  return _TreePhoto(path: photoPath!, fit: BoxFit.cover);
                }
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E7D32), ColorConstants.forestGreen],
                    ),
                  ),
                );
              },
            ),
            // Dark scrim for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tree.species ?? '—',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (widget.tree.plantingDate != null)
              Text(
                '${t.plantedOn}  ${DateFormat('dd MMM yyyy').format(widget.tree.plantingDate!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(AppText t) {
    final lat = widget.tree.latitude;
    final lng = widget.tree.longitude;
    final planted = widget.tree.plantingDate;
    final daysGrowing = planted != null
        ? DateTime.now().difference(planted).inDays
        : null;
    final notes = widget.tree.notes;

    final category = _details?['category'] ?? widget.tree.sponsorshipCategory;
    final status = _details?['status'] as String?;
    final initial = _details?['initialPhoto'] as String?;
    final latest = _updates.firstOrNull;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(t.treeDetails),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.qr_code,
            label: 'Tree ID',
            value:
                (_details?['qrCode'] ?? widget.tree.serverId ?? widget.tree.id)
                    .toString(),
          ),
          if (category != null)
            _InfoRow(
              icon: Icons.eco_outlined,
              label: 'Sponsorship',
              value: switch (category) {
                'corporate' => 'Corporate',
                'individual' => 'Individual',
                _ => 'Unsponsored',
              },
            ),
          for (final (label, key) in [
            ('Sponsor', 'sponsor'),
            ('Campaign', 'campaign'),
            ('Order', 'orderId'),
            ('Batch', 'batchId'),
            ('Planting session', 'sessionId'),
          ])
            if ((_details?[key] as String?)?.isNotEmpty == true)
              _InfoRow(
                icon: Icons.info_outline,
                label: label,
                value: _details![key] as String,
              ),
          if (planted != null)
            _InfoRow(
              icon: Icons.event_outlined,
              label: t.plantedOn,
              value: DateFormat.yMMMd().format(planted),
            ),
          _InfoRow(
            icon: Icons.health_and_safety_outlined,
            label: 'Survival status',
            value:
                widget.tree.isDead ||
                    status == 'dead' ||
                    _currentStage == GrowthStage.dead
                ? 'Dead'
                : status == 'replaced'
                ? 'Replaced'
                : status == 'needs_water'
                ? 'Needs attention'
                : 'Alive',
          ),
          if (latest?.recordedByName?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Latest update by',
              value: latest!.recordedByName!,
            ),
          if (initial != null && initial.isNotEmpty) ...[
            const Text('Initial planting photo'),
            const SizedBox(height: 6),
            _TreePhoto(path: initial, height: 120, fit: BoxFit.cover),
          ],
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: t.plotLabel,
            value: widget.tree.plotName ?? widget.tree.plotId,
          ),
          _InfoRow(
            icon: Icons.map_outlined,
            label: t.regionLabel,
            value: widget.tree.regionName ?? t.regionUnassigned,
          ),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: t.plantedBy,
            value: widget.tree.plantedBy ?? t.unknownPlanter,
          ),
          _InfoRow(
            icon: Icons.my_location_rounded,
            label: 'GPS',
            value: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
          ),
          if (daysGrowing != null)
            _InfoRow(
              icon: Icons.calendar_today_rounded,
              label: t.daysGrowing,
              value: '$daysGrowing days',
            ),
          if (notes != null && notes.isNotEmpty)
            _InfoRow(
              icon: Icons.notes_rounded,
              label: t.workerNotesLabel,
              value: notes,
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStageCard(AppText t) {
    final stage = _currentStage;
    final (icon, color) = _stageStyle(stage);
    final label = _stageName(stage, t);

    return _Card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.currentStage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorConstants.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(AppText t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.growthHistory.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: ColorConstants.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_updates.isEmpty)
          _emptyHistory(t)
        else
          ...List.generate(_updates.length, (i) {
            final u = _updates[i];
            return _TimelineTile(
              update: u,
              isFirst: i == 0,
              isLast: i == _updates.length - 1,
              t: t,
            );
          }),
      ],
    );
  }

  Widget _emptyHistory(AppText t) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.timeline_rounded,
            size: 36,
            color: ColorConstants.lightTextSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            t.noUpdatesYet,
            style: const TextStyle(
              fontSize: 14,
              color: ColorConstants.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: ColorConstants.lightTextSecondary,
    ),
  );

  static (IconData, Color) _stageStyle(GrowthStage s) => switch (s) {
    GrowthStage.planted => (Icons.eco_rounded, const Color(0xFF4CAF50)),
    GrowthStage.sprouting => (Icons.nature_rounded, const Color(0xFF81C784)),
    GrowthStage.growing => (Icons.park_rounded, ColorConstants.forestGreen),
    GrowthStage.established => (Icons.forest_rounded, const Color(0xFF2E7D32)),
    GrowthStage.needsAttention => (
      Icons.warning_amber_rounded,
      ColorConstants.warningColor,
    ),
    GrowthStage.dead => (
      Icons.sentiment_very_dissatisfied_rounded,
      ColorConstants.errorColor,
    ),
  };

  static String _stageName(GrowthStage s, AppText t) => switch (s) {
    GrowthStage.planted => t.stagePlanted,
    GrowthStage.sprouting => t.stageSprouting,
    GrowthStage.growing => t.stageGrowing,
    GrowthStage.established => t.stageEstablished,
    GrowthStage.needsAttention => t.stageNeedsAttention,
    GrowthStage.dead => t.stageDead,
  };
}

// ── Timeline tile ─────────────────────────────────────────────────────────────

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.update,
    required this.isFirst,
    required this.isLast,
    required this.t,
  });

  final TreeGrowthUpdateModel update;
  final bool isFirst;
  final bool isLast;
  final AppText t;

  static (IconData, Color) _stageStyle(GrowthStage s) =>
      _WorkerTreeDetailScreenState._stageStyle(s);
  static String _stageName(GrowthStage s, AppText t) =>
      _WorkerTreeDetailScreenState._stageName(s, t);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _stageStyle(update.stage);
    final label = _stageName(update.stage, t);
    final dateStr = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(update.recordedAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline spine ──────────────────────────────────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: ColorConstants.borderGrey,
                      ),
                    ),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                if (!isLast)
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: ColorConstants.borderGrey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isFirst
                    ? color.withValues(alpha: 0.06)
                    : ColorConstants.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFirst
                      ? color.withValues(alpha: 0.3)
                      : ColorConstants.borderGrey,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StageBadge(label: label, color: color),
                      if (isFirst) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ColorConstants.forestGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'LATEST',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                  if (update.heightCm != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.height_rounded,
                          size: 14,
                          color: ColorConstants.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${update.heightCm!.toStringAsFixed(1)} cm',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ColorConstants.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (update.recordedByName?.isNotEmpty == true)
                    Text(
                      'Recorded by ${update.recordedByName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (update.notes != null && update.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      update.notes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                  ],
                  if (update.photoPath != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _TreePhoto(
                        key: ValueKey(update.photoPath),
                        path: update.photoPath!,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ColorConstants.lightTextSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: ColorConstants.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
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

ImageProvider _growthPhoto(String path) {
  if (path.startsWith('/api/')) {
    return NetworkImage(
      Uri.parse(resolveApiBaseUrl()).resolve(path).toString(),
    );
  }
  final scheme = Uri.tryParse(path)?.scheme;
  if (kIsWeb || scheme == 'https' || scheme == 'http') {
    return NetworkImage(path);
  }
  return FileImage(File(path));
}

class _TreePhoto extends StatefulWidget {
  const _TreePhoto({
    super.key,
    required this.path,
    this.height,
    required this.fit,
  });
  final String path;
  final double? height;
  final BoxFit fit;

  @override
  State<_TreePhoto> createState() => _TreePhotoState();
}

class _TreePhotoState extends State<_TreePhoto> {
  Future<List<int>>? _load;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _TreePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) _prepare();
  }

  void _prepare() {
    final path = widget.path;
    _load =
        path.startsWith('/api/v1/media/plantation_photo/') ||
            path.startsWith('/api/v1/media/growth_photo/')
        ? getIt<FieldApiService>().loadPlantationPhoto(path)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_load == null) {
      return Image(
        image: _growthPhoto(widget.path),
        height: widget.height,
        width: double.infinity,
        fit: widget.fit,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return FutureBuilder<List<int>>(
      future: _load,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null || data.isEmpty) {
          return SizedBox(height: widget.height);
        }
        return Image.memory(
          Uint8List.fromList(data),
          height: widget.height,
          width: double.infinity,
          fit: widget.fit,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      },
    );
  }
}
