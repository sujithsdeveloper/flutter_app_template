import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';
import 'package:mess_app/data/repositories/worker_plot_repository.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';

/// Pulls field data from the backend and upserts into local SQLite so the
/// offline-first UI keeps working after a sync.
class FieldSyncService {
  FieldSyncService({
    required FieldApiService api,
    required PlotRepository plotRepository,
    required WorkerRepository workerRepository,
    required WorkerPlotRepository workerPlotRepository,
    required TreeTaskRepository taskRepository,
    required SyncRepository syncRepository,
  }) : _api = api,
       _plots = plotRepository,
       _workers = workerRepository,
       _workerPlots = workerPlotRepository,
       _tasks = taskRepository,
       _sync = syncRepository;

  final FieldApiService _api;
  final PlotRepository _plots;
  final WorkerRepository _workers;
  final WorkerPlotRepository _workerPlots;
  final TreeTaskRepository _tasks;
  final SyncRepository _sync;

  Future<void> pullAndApply() async {
    final payload = await _api.fieldSync();
    await applyPayload(payload);
  }

  Future<void> applyPayload(Map<String, dynamic> payload) async {
    final now = DateTime.now();

    final accessCode = payload['accessCode'];
    if (accessCode is String && accessCode.isNotEmpty) {
      await _sync.setMetaValue(DbConstants.metaKeyAuthVolCode, accessCode);
    }

    // Full replace so local SQLite never keeps seed/orphan plots that are
    // not in the admin/API list for this volunteer.
    final plots = payload['plots'];
    final syncedPlots = <PlotModel>[];
    if (plots is List) {
      for (final raw in plots) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final apiStatus = (map['status'] ?? '').toString().toLowerCase();
        if (apiStatus == 'retired') continue;
        final id = (map['id'] ?? '').toString();
        if (id.isEmpty) continue;
        syncedPlots.add(_plotFromApi(map, now));
      }
    }
    await _plots.replaceAll(syncedPlots);

    final workers = payload['workers'];
    if (workers is List) {
      for (final raw in workers) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final worker = _workerFromApi(map, now);
        await _workers.upsert(worker);

        final plotIds = map['plotIds'];
        if (plotIds is List) {
          await _workerPlots.setAssignments(
            worker.id,
            plotIds.map((e) => e.toString()).toList(),
          );
        }
      }
    }

    final tasks = payload['tasks'];
    final syncedTasks = <TreeTaskModel>[];
    if (tasks is List) {
      for (final raw in tasks) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        syncedTasks.add(_taskFromApi(map, now));
      }
    }
    await _tasks.replaceAll(syncedTasks);

    await _sync.setLastSyncTime(now);
    AppLogger.response('[FieldSyncService] sync applied');
  }

  PlotModel _plotFromApi(Map<String, dynamic> m, DateTime now) {
    final id = (m['id'] ?? '').toString();
    final acres = (m['areaAcres'] as num?)?.toDouble();
    final hectares = acres != null ? acres * 0.404686 : null;
    final location = (m['location'] as String?)?.trim();
    final regionName = (m['regionName'] as String?)?.trim();
    final owner = (m['ownerInfo'] as String?)?.trim();

    return PlotModel(
      id: id,
      serverId: id,
      name: (m['name'] ?? 'Plot').toString(),
      location: (location != null && location.isNotEmpty)
          ? location
          : (regionName != null && regionName.isNotEmpty)
          ? regionName
          : (owner != null && owner.isNotEmpty)
          ? owner
          : 'Unspecified',
      district: (m['district'] as String?)?.isEmpty ?? true
          ? null
          : m['district'] as String?,
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      areaHectares: hectares,
      treeCount: (m['treeCount'] as num?)?.toInt() ?? 0,
      status: PlotStatus.healthy,
      assignedVolunteerId:
          (m['assignedVolunteerId'] as String?)?.isEmpty ?? true
          ? null
          : m['assignedVolunteerId'] as String?,
      syncStatus: SyncStatus.synced,
      createdAt: _parseTime(m['createdAt']) ?? now,
      updatedAt: now,
      syncedAt: now,
    );
  }

  WorkerModel _workerFromApi(Map<String, dynamic> m, DateTime now) {
    final id = (m['id'] ?? '').toString();
    return WorkerModel(
      id: id,
      serverId: id,
      name: (m['name'] ?? 'Worker').toString(),
      phone: (m['phone'] as String?)?.isEmpty ?? true
          ? null
          : m['phone'] as String?,
      photoPath: (m['photoUrl'] as String?)?.isEmpty ?? true
          ? null
          : m['photoUrl'] as String?,
      volunteerId: (m['volunteerId'] as String?)?.isEmpty ?? true
          ? null
          : m['volunteerId'] as String?,
      isActive: m['isActive'] as bool? ?? true,
      syncStatus: SyncStatus.synced,
      createdAt: _parseTime(m['createdAt']) ?? now,
      updatedAt: _parseTime(m['updatedAt']) ?? now,
      syncedAt: now,
    );
  }

  TreeTaskModel _taskFromApi(Map<String, dynamic> m, DateTime now) {
    final id = (m['id'] ?? '').toString();
    final target = m['targetDate'] as String?;
    final treeIdRaw = (m['treeId'] as String?)?.trim();
    final regionIdRaw = (m['regionId'] as String?)?.trim();
    final regionNameRaw = (m['regionName'] as String?)?.trim();
    final plotNameRaw = (m['plotName'] as String?)?.trim();
    final workerNameRaw = (m['workerName'] as String?)?.trim();
    final sponsorshipRaw = (m['sponsorshipId'] as String?)?.trim();
    final intentRaw = (m['sponsorIntent'] as String?)?.trim();
    final programNameRaw = (m['programName'] as String?)?.trim();
    return TreeTaskModel(
      id: id,
      serverId: id,
      plotId: (m['plotId'] ?? '').toString(),
      plotName: (plotNameRaw == null || plotNameRaw.isEmpty)
          ? null
          : plotNameRaw,
      species: (m['species'] ?? '').toString(),
      latitude: (m['lat'] as num?)?.toDouble() ?? 0,
      longitude: (m['lng'] as num?)?.toDouble() ?? 0,
      notes: (m['notes'] as String?)?.isEmpty ?? true
          ? null
          : m['notes'] as String?,
      adminNotes: (m['adminNotes'] as String?)?.isEmpty ?? true
          ? null
          : m['adminNotes'] as String?,
      sponsorIntent: (intentRaw == null || intentRaw.isEmpty)
          ? null
          : intentRaw,
      programName: (programNameRaw == null || programNameRaw.isEmpty)
          ? null
          : programNameRaw,
      targetDate: (target != null && target.isNotEmpty)
          ? DateTime.tryParse(target)
          : null,
      volunteerId: (m['volunteerId'] as String?)?.isEmpty ?? true
          ? null
          : m['volunteerId'] as String?,
      workerId: (m['workerId'] as String?)?.isEmpty ?? true
          ? null
          : m['workerId'] as String?,
      workerName: (workerNameRaw == null || workerNameRaw.isEmpty)
          ? null
          : workerNameRaw,
      photoPath: (m['photoUrl'] as String?)?.isEmpty ?? true
          ? null
          : m['photoUrl'] as String?,
      treeId: (treeIdRaw == null || treeIdRaw.isEmpty) ? null : treeIdRaw,
      regionId: (regionIdRaw == null || regionIdRaw.isEmpty)
          ? null
          : regionIdRaw,
      regionName: (regionNameRaw == null || regionNameRaw.isEmpty)
          ? null
          : regionNameRaw,
      sponsorshipId: (sponsorshipRaw == null || sponsorshipRaw.isEmpty)
          ? null
          : sponsorshipRaw,
      taskStatus: TaskStatus.fromValue(
        (m['taskStatus'] ?? 'pending').toString(),
      ),
      syncStatus: SyncStatus.synced,
      createdAt: _parseTime(m['createdAt']) ?? now,
      updatedAt: _parseTime(m['updatedAt']) ?? now,
      syncedAt: now,
    );
  }

  DateTime? _parseTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
