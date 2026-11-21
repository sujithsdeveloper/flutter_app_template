import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/data/models/tree_growth_update_model.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/data/repositories/tree_growth_repository.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';
import 'package:mess_app/presentation/widgets/tree_photo_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Allows the assigned planter to update a task:
/// - Capture current GPS
/// - Take a photo of the plant / site
/// - Add notes
/// - Mark as Planted (creates a [TreeModel] record)
/// - Mark as Can't Plant (cancels the task with a reason)
class TaskUpdateScreen extends StatefulWidget {
  const TaskUpdateScreen({
    super.key,
    required this.task,
    required this.session,
  });

  final TreeTaskModel task;
  final UserSession session;

  @override
  State<TaskUpdateScreen> createState() => _TaskUpdateScreenState();
}

class _TaskUpdateScreenState extends State<TaskUpdateScreen> {
  final _notesCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _taskRepo = getIt<TreeTaskRepository>();
  final _growthRepo = getIt<TreeGrowthRepository>();
  final _treeRepo = getIt<TreeRepository>();
  final _fieldApi = getIt<FieldApiService>();

  Position? _position;
  String? _photoPath;
  bool _loadingGps = false;
  bool _saving = false;

  bool get _isFieldAdmin => widget.session.role.isAdminVolunteer;
  String get _draftKey =>
      'personal-planting.${widget.session.role.value}.${widget.session.userId}.${widget.task.id}';

  @override
  void dispose() {
    _notesCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _captureGps(AppText t) async {
    setState(() => _loadingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        SnackbarHelper.showError(
          context: context,
          message: 'Location access denied. Open app settings to allow.',
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() => _position = pos);
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context: context,
        message: 'Could not get location. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _takePhoto(AppText t) async {
    final path = await captureTreePhoto(context, t);
    if (mounted && path != null) setState(() => _photoPath = path);
  }

  // ── Save actions ──────────────────────────────────────────────────────────

  Future<void> _recordBatch(AppText t) async {
    if (_saving) return;
    setState(() => _saving = true);
    var savedOnDevice = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final existing = preferences.getString(_draftKey);
      Map<String, dynamic> draft;
      if (existing != null) {
        draft = jsonDecode(existing) as Map<String, dynamic>;
        savedOnDevice = true;
      } else {
        final quantity = int.tryParse(_quantityCtrl.text.trim());
        if (quantity == null ||
            quantity < 1 ||
            quantity > widget.task.batchRemaining) {
          throw StateError(
            'Enter 1–${widget.task.batchRemaining} planted trees.',
          );
        }
        final notes = _notesCtrl.text.trim();
        if (notes.length > 500) {
          throw StateError('Keep session notes to 500 characters.');
        }
        final position = _position;
        if (position == null) throw StateError(t.gpsRequired);
        final image = _photoPath == null
            ? null
            : await XFile(_photoPath!).readAsBytes();
        if (image != null && image.length > 2 * 1024 * 1024) {
          throw StateError('Capture a photo smaller than 2 MB.');
        }
        draft = {
          'payload': {
            'submissionKey': const Uuid().v4(),
            'quantity': quantity,
            'lat': position.latitude,
            'lng': position.longitude,
            'notes': notes,
          },
          if (image != null) 'photo': base64Encode(image),
        };
        savedOnDevice = await preferences.setString(
          _draftKey,
          jsonEncode(draft),
        );
        if (!savedOnDevice) {
          throw StateError(
            'Could not save the planting session on this device.',
          );
        }
      }
      final payload = draft['payload'] as Map<String, dynamic>;
      final image = draft['photo'] as String?;
      if (image != null && payload['photoUrl'] == null) {
        payload['photoUrl'] = await _fieldApi.uploadPlantationPhoto(
          base64Decode(image),
        );
        draft.remove('photo');
        await preferences.setString(_draftKey, jsonEncode(draft));
      }
      final row = await _fieldApi.recordPersonalPlantingSession(
        widget.task.id,
        payload,
      );
      await preferences.remove(_draftKey);
      savedOnDevice = false;
      final sync = getIt<FieldSyncService>();
      await sync.cacheTask(row);
      try {
        await sync.pullAndApply();
      } catch (error) {
        AppLogger.error(
          '[TaskUpdateScreen] batch recorded, refresh deferred: $error',
        );
      }
      if (!mounted) return;
      SnackbarHelper.showSucces(
        context: context,
        message: 'Planting session recorded.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : FieldApiService.messageOf(error);
      SnackbarHelper.showError(
        context: context,
        message: savedOnDevice
            ? 'Session saved on this device. Tap Record session to retry. $message'
            : message,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markAsPlanted(AppText t) async {
    if (widget.task.isPlantingBatch) return _recordBatch(t);
    if (_position == null) {
      SnackbarHelper.showError(context: context, message: t.gpsRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      // Prefer the sponsored backend tree id so donor My Trees updates in place.
      final linkedTreeId = widget.task.treeId;
      final treeId = linkedTreeId ?? widget.task.id;
      final plot = await getIt<PlotRepository>().getById(widget.task.plotId);
      var syncStatus = SyncStatus.pending;
      var growthId = _isFieldAdmin ? widget.task.id : const Uuid().v4();
      var growthStatus = SyncStatus.pending;
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();

      // Upload the captured photo using the same private storage as growth evidence.
      String? photoUrl;
      try {
        if (linkedTreeId != null && _photoPath != null) {
          photoUrl = await _fieldApi.uploadGrowthPhoto(
            await XFile(_photoPath!).readAsBytes(),
          );
        }
        await _fieldApi.updateTreeTask(
          widget.task.id,
          taskStatus: 'planted',
          notes: notes,
          photoUrl: photoUrl,
          lat: _position!.latitude,
          lng: _position!.longitude,
        );
        syncStatus = SyncStatus.synced;
      } catch (e) {
        if (_isFieldAdmin || !FieldApiService.isOfflineError(e)) rethrow;
        AppLogger.error('[TaskUpdateScreen] remote plant deferred: $e');
      }

      if (linkedTreeId != null && syncStatus == SyncStatus.synced) {
        if (_isFieldAdmin) {
          growthStatus = SyncStatus.synced;
        } else {
          try {
            final growth = await _fieldApi.createGrowthUpdate(
              treeId: linkedTreeId,
              stage: GrowthStage.planted.value,
              notes: notes,
              photoUrl: photoUrl,
              recordedBy: widget.session.userId,
            );
            growthId = growth['id'] as String? ?? growthId;
            growthStatus = SyncStatus.synced;
          } catch (e) {
            AppLogger.error('[TaskUpdateScreen] planting history deferred: $e');
          }
        }
      }

      // 1. Local planted tree record (offline cache / worker My Trees).
      if (await _treeRepo.getById(treeId) == null) {
        await _treeRepo.insert(
          TreeModel(
            id: treeId,
            serverId: syncStatus == SyncStatus.synced ? linkedTreeId : null,
            plotId: widget.task.plotId,
            plotName: plot?.name ?? widget.task.plotName,
            regionName: plot?.regionName ?? widget.task.regionName,
            plantedBy: widget.session.userName,
            plantedById: widget.session.userId,
            species: widget.task.species,
            plantingDate: now,
            latitude: _position!.latitude,
            longitude: _position!.longitude,
            gpsAccuracy: _position!.accuracy,
            notes: notes,
            workerId: _isFieldAdmin ? null : widget.session.userId,
            syncStatus: linkedTreeId != null ? syncStatus : SyncStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // 2. Mark the task as planted with photo + notes.
      await _taskRepo.markAsPlanted(
        widget.task.id,
        notes: notes,
        photoPath: _photoPath,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        syncStatus: syncStatus,
      );

      // 3. Seed the initial "Planted" growth-stage entry locally.
      if (!_isFieldAdmin || await _growthRepo.getLatest(treeId) == null) {
        await _growthRepo.insert(
          TreeGrowthUpdateModel(
            id: growthId,
            treeId: treeId,
            stage: GrowthStage.planted,
            notes: notes,
            photoPath: _photoPath,
            recordedBy: widget.session.userId,
            recordedAt: now,
            syncStatus: growthStatus,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (!mounted) return;
      SnackbarHelper.showSucces(context: context, message: t.taskUpdated);
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

  Future<void> _cantPlant(AppText t) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t.cantPlant,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            hintText: t.cantPlantReasonHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t.cancel,
              style: const TextStyle(color: ColorConstants.lightTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorConstants.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t.cantPlant),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (!mounted || reason == null || reason.isEmpty) return;

    setState(() => _saving = true);
    try {
      if (_isFieldAdmin || widget.task.isPlantingBatch) {
        await _fieldApi.updateTreeTask(
          widget.task.id,
          taskStatus: 'cancelled',
          notes: reason,
        );
      }
      await _taskRepo.cancelTask(
        widget.task.id,
        reason: reason,
        syncStatus: _isFieldAdmin || widget.task.isPlantingBatch
            ? SyncStatus.synced
            : SyncStatus.pending,
      );
      if (!mounted) return;
      SnackbarHelper.showSucces(context: context, message: t.taskCancelled);
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
              t.updateTask,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Task info ─────────────────────────────────────
                    _buildTaskInfoCard(t),
                    const SizedBox(height: 16),

                    if (widget.task.isPlantingBatch) ...[
                      Text(
                        '${widget.task.batchPlanted} of ${widget.task.batchQuantity} trees planted',
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _quantityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Trees planted in this session',
                          helperText: '${widget.task.batchRemaining} remaining',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── GPS section ───────────────────────────────────
                    _buildGpsSection(t),
                    const SizedBox(height: 16),

                    // ── Photo section ─────────────────────────────────
                    _buildPhotoSection(t),
                    const SizedBox(height: 16),

                    // ── Notes ─────────────────────────────────────────
                    _buildNotesSection(t),
                  ],
                ),
              ),
              // ── Fixed bottom buttons ──────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildActionButtons(t),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Section builders ──────────────────────────────────────────────────────

  Widget _buildTaskInfoCard(AppText t) {
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorConstants.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.park_rounded,
                  size: 22,
                  color: ColorConstants.forestGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.task.species,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: t.targetLocation,
            value: widget.task.locationLabel,
          ),
          if (widget.task.adminNotes != null &&
              widget.task.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.sticky_note_2_outlined,
              label: t.adminNotesLabel,
              value: widget.task.adminNotes!,
            ),
          ],
          if (widget.task.targetDate != null) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: t.targetDate,
              value: _formatDate(widget.task.targetDate!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsSection(AppText t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _position != null
              ? ColorConstants.successColor.withValues(alpha: 0.4)
              : ColorConstants.borderGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _position != null
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                size: 20,
                color: _position != null
                    ? ColorConstants.successColor
                    : ColorConstants.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                t.gpsLocation,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.lightTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _position != null
                      ? ColorConstants.successColor
                      : ColorConstants.warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_position != null) ...[
            _CoordRow(
              label: 'Lat',
              value: _position!.latitude.toStringAsFixed(6),
            ),
            const SizedBox(height: 4),
            _CoordRow(
              label: 'Lng',
              value: _position!.longitude.toStringAsFixed(6),
            ),
            const SizedBox(height: 4),
            _CoordRow(
              label: 'Accuracy',
              value: '±${_position!.accuracy.toStringAsFixed(1)} m',
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              t.gpsNotCaptured,
              style: const TextStyle(
                fontSize: 13,
                color: ColorConstants.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              icon: _loadingGps
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ColorConstants.forestGreen,
                        ),
                      ),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _loadingGps
                    ? t.gettingLocation
                    : (_position != null ? t.retryGps : t.captureGps),
              ),
              onPressed: _loadingGps ? null : () => _captureGps(t),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorConstants.forestGreen,
                side: const BorderSide(color: ColorConstants.forestGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(AppText t) {
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
              const Icon(
                Icons.photo_camera_rounded,
                size: 20,
                color: ColorConstants.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                t.photoOptional,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_photoPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_photoPath!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
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
          ] else ...[
            GestureDetector(
              onTap: () => _takePhoto(t),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ColorConstants.lightBackgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ColorConstants.borderGrey,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: ColorConstants.lightTextSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.takePhoto,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ColorConstants.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesSection(AppText t) {
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
              const Icon(
                Icons.notes_rounded,
                size: 20,
                color: ColorConstants.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                t.workerNotesLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _notesCtrl,
            labelText: '',
            hintText: t.workerNotesHint,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppText t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: ColorConstants.lightBackground,
        border: Border(top: BorderSide(color: ColorConstants.borderGrey)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => _cantPlant(t),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorConstants.errorColor,
                side: const BorderSide(color: ColorConstants.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                t.cantPlant,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: widget.task.isPlantingBatch
                  ? 'Record session'
                  : t.markAsPlanted,
              icon: Icons.check_circle_outline_rounded,
              isLoading: _saving,
              onPressed: _saving ? null : () => _markAsPlanted(t),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Helper widgets ────────────────────────────────────────────────────────────

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: ColorConstants.lightTextSecondary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: ColorConstants.lightTextSecondary,
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
    );
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: ColorConstants.lightTextSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColorConstants.lightTextPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
