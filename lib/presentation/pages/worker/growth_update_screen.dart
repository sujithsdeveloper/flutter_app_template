import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:mess_app/data/models/tree_growth_update_model.dart';
import 'package:mess_app/data/repositories/tree_growth_repository.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';
import 'package:mess_app/presentation/widgets/tree_photo_capture.dart';
import 'package:uuid/uuid.dart';

/// Records a new [TreeGrowthUpdateModel] for a planted tree.
/// Returns [true] via Navigator.pop when a record is saved.
class GrowthUpdateScreen extends StatefulWidget {
  const GrowthUpdateScreen({
    super.key,
    required this.treeId,
    required this.workerId,
    required this.species,
    this.requireServerSave = false,
    this.cacheLocally = true,
  });

  final String treeId;
  final String workerId;
  final String? species;
  final bool requireServerSave;
  final bool cacheLocally;

  @override
  State<GrowthUpdateScreen> createState() => _GrowthUpdateScreenState();
}

class _GrowthUpdateScreenState extends State<GrowthUpdateScreen> {
  GrowthStage _stage = GrowthStage.growing;
  final _heightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _photoPath;
  bool _saving = false;

  final _repo = getIt<TreeGrowthRepository>();
  final _fieldApi = getIt<FieldApiService>();

  @override
  void dispose() {
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _takePhoto(AppText t) async {
    final path = await captureTreePhoto(context, t);
    if (mounted && path != null) setState(() => _photoPath = path);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save(AppText t) async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final heightCm = double.tryParse(_heightCtrl.text.trim());
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();

      var syncStatus = SyncStatus.pending;
      var updateId = const Uuid().v4();
      var storedPhoto = _photoPath;
      try {
        final uploaded = _photoPath == null
            ? null
            : await _fieldApi.uploadGrowthPhoto(
                await XFile(_photoPath!).readAsBytes(),
              );
        final saved = await _fieldApi.createGrowthUpdate(
          treeId: widget.treeId,
          stage: _stage.value,
          heightCm: heightCm,
          notes: notes,
          photoUrl: uploaded,
          recordedBy: widget.workerId,
        );
        updateId = saved['id'] as String? ?? updateId;
        syncStatus = SyncStatus.synced;
        storedPhoto = uploaded;
      } catch (e) {
        if (widget.requireServerSave) rethrow;
        AppLogger.error('[GrowthUpdateScreen] remote save deferred: $e');
      }

      if (widget.cacheLocally) {
        await _repo.insert(
          TreeGrowthUpdateModel(
            id: updateId,
            treeId: widget.treeId,
            stage: _stage,
            heightCm: heightCm,
            notes: notes,
            photoPath: storedPhoto,
            recordedBy: widget.workerId,
            recordedAt: now,
            syncStatus: syncStatus,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      if (!mounted) return;
      SnackbarHelper.showSucces(context: context, message: t.updateSaved);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context: context,
        message: FieldApiService.messageOf(e),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, lang, _) {
        final t = AppText(lang);
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
              t.growthUpdateTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorConstants.lightTextPrimary,
              ),
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tree name chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ColorConstants.softGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.park_rounded,
                            size: 14,
                            color: ColorConstants.forestGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.species ?? '—',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ColorConstants.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Stage selector ────────────────────────────────
                    _sectionLabel(t.selectStage),
                    const SizedBox(height: 10),
                    _StageSelector(
                      selected: _stage,
                      onSelect: (s) => setState(() => _stage = s),
                      t: t,
                    ),
                    const SizedBox(height: 20),

                    // ── Height ────────────────────────────────────────
                    _sectionLabel(t.heightCm),
                    const SizedBox(height: 8),
                    _card(
                      child: TextField(
                        controller: _heightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: t.heightHint,
                          hintStyle: const TextStyle(
                            color: ColorConstants.lightTextSecondary,
                          ),
                          suffixText: 'cm',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Photo ─────────────────────────────────────────
                    _sectionLabel(t.photoOptional),
                    const SizedBox(height: 8),
                    _buildPhotoSection(t),
                    const SizedBox(height: 16),

                    // ── Notes ─────────────────────────────────────────
                    _sectionLabel(t.workerNotesLabel),
                    const SizedBox(height: 8),
                    _card(
                      child: TextField(
                        controller: _notesCtrl,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: t.workerNotesHint,
                          hintStyle: const TextStyle(
                            color: ColorConstants.lightTextSecondary,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Fixed save button ─────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: const BoxDecoration(
                    color: ColorConstants.lightBackground,
                    border: Border(
                      top: BorderSide(color: ColorConstants.borderGrey),
                    ),
                  ),
                  child: PrimaryButton(
                    label: t.addGrowthUpdate,
                    icon: Icons.save_rounded,
                    isLoading: _saving,
                    onPressed: _saving ? null : () => _save(t),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoSection(AppText t) {
    if (_photoPath != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_photoPath!),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retake'),
                  onPressed: () => _takePhoto(t),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorConstants.lightTextSecondary,
                    side: const BorderSide(color: ColorConstants.borderGrey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove'),
                  onPressed: () => setState(() => _photoPath = null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorConstants.errorColor,
                    side: const BorderSide(
                      color: ColorConstants.errorColor,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () => _takePhoto(t),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: ColorConstants.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorConstants.borderGrey),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              size: 28,
              color: ColorConstants.lightTextSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              t.takePhoto,
              style: const TextStyle(
                fontSize: 13,
                color: ColorConstants.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: ColorConstants.lightTextSecondary,
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: ColorConstants.lightCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ColorConstants.borderGrey),
    ),
    child: child,
  );
}

// ── Stage selector ────────────────────────────────────────────────────────────

class _StageSelector extends StatelessWidget {
  const _StageSelector({
    required this.selected,
    required this.onSelect,
    required this.t,
  });

  final GrowthStage selected;
  final ValueChanged<GrowthStage> onSelect;
  final AppText t;

  @override
  Widget build(BuildContext context) {
    final stages = [
      GrowthStage.planted,
      GrowthStage.sprouting,
      GrowthStage.growing,
      GrowthStage.established,
      GrowthStage.needsAttention,
      GrowthStage.dead,
    ];
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stages
          .map(
            (s) => _StageCard(
              stage: s,
              selected: s == selected,
              label: _stageLabel(s),
              onTap: () => onSelect(s),
            ),
          )
          .toList(),
    );
  }

  String _stageLabel(GrowthStage s) => switch (s) {
    GrowthStage.planted => t.stagePlanted,
    GrowthStage.sprouting => t.stageSprouting,
    GrowthStage.growing => t.stageGrowing,
    GrowthStage.established => t.stageEstablished,
    GrowthStage.needsAttention => t.stageNeedsAttention,
    GrowthStage.dead => t.stageDead,
  };
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final GrowthStage stage;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  static (IconData, Color) _meta(GrowthStage s) => switch (s) {
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

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _meta(stage);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : ColorConstants.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : ColorConstants.borderGrey,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : ColorConstants.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
