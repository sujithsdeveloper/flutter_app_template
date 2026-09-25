import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';

import 'dashboard_state.dart';

/// Drives the home/dashboard screen.
///
/// Loads all metrics — plots, trees, workers, sync queue — from the local
/// SQLite DB in a single [Future.wait] batch. Subscribes to connectivity
/// changes and auto-triggers sync when the device comes back online.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required PlotRepository plotRepository,
    required TreeRepository treeRepository,
    required SyncRepository syncRepository,
    required WorkerRepository workerRepository,
    required TreeTaskRepository taskRepository,
    required FieldSyncService fieldSyncService,
    required FieldApiService fieldApi,
  })  : _plotRepo = plotRepository,
        _treeRepo = treeRepository,
        _syncRepo = syncRepository,
        _workerRepo = workerRepository,
        _taskRepo = taskRepository,
        _fieldSync = fieldSyncService,
        _api = fieldApi,
        super(DashboardState.initial()) {
    _init();
  }

  final PlotRepository _plotRepo;
  final TreeRepository _treeRepo;
  final SyncRepository _syncRepo;
  final WorkerRepository _workerRepo;
  final TreeTaskRepository _taskRepo;
  final FieldSyncService _fieldSync;
  final FieldApiService _api;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  static double? _hectaresToAcres(double? hectares) {
    if (hectares == null) return null;
    return hectares / 0.404686;
  }

  // ── Initialisation ───────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      emit(state.copyWith(isOnline: online));
    } catch (_) {
      emit(state.copyWith(isOnline: false));
    }

    await _loadDashboard();

    // Always pull region-scoped sponsorship tasks on open so volunteers see
    // new planting work without hunting for the sync button.
    if (state.isOnline) {
      // Fire-and-forget; triggerSync guards against re-entry.
      // ignore: unawaited_futures
      triggerSync();
    }

    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        emit(state.copyWith(isOnline: online));
        if (online && !state.isSyncing) {
          triggerSync();
        }
      },
      onError: (_) => emit(state.copyWith(isOnline: false)),
    );
  }

  // ── Public API ───────────────────────────────────────────────────────────

  Future<void> refresh() => _loadDashboard();

  /// Plot creation is staff-only (web admin). Volunteers cannot create plots.
  Future<bool> addPlot({
    required String name,
    required String location,
    String? district,
    double? latitude,
    double? longitude,
    double? areaHectares,
    String? volunteerId,
  }) async {
    AppLogger.error(
      '[DashboardCubit] addPlot blocked: create plots from web admin only',
    );
    emit(
      state.copyWith(
        errorMessage: 'Plots can only be added from the web admin panel',
      ),
    );
    return false;
  }

  /// Updates an existing plot locally and via API when possible.
  Future<bool> updatePlot({
    required String plotId,
    required String name,
    required String location,
    String? district,
    double? latitude,
    double? longitude,
    double? areaHectares,
  }) async {
    if (name.trim().isEmpty || location.trim().isEmpty) return false;

    try {
      final existing = await _plotRepo.getById(plotId);
      if (existing == null) return false;

      final remoteId = existing.serverId ?? existing.id;
      var syncStatus = SyncStatus.pending;
      String? serverId = existing.serverId;

      try {
        final remote = await _api.updatePlot(
          remoteId,
          name: name,
          location: location,
          district: district,
          latitude: latitude,
          longitude: longitude,
          areaAcres: _hectaresToAcres(areaHectares),
        );
        serverId = (remote['id'] ?? remoteId).toString();
        syncStatus = SyncStatus.synced;
      } catch (e) {
        AppLogger.error(
          '[DashboardCubit] remote update plot failed, saving offline: $e',
        );
      }

      await _plotRepo.update(
        id: plotId,
        name: name,
        location: location,
        district: district,
        latitude: latitude,
        longitude: longitude,
        areaHectares: areaHectares,
        syncStatus: syncStatus,
        serverId: serverId,
      );
      AppLogger.request('[DashboardCubit] plot updated: $plotId');
      await _loadDashboard();
      return true;
    } catch (e) {
      AppLogger.error('[DashboardCubit] updatePlot error: $e');
      emit(state.copyWith(errorMessage: e.toString()));
      return false;
    }
  }

  /// Marks a plot as retired on the server and removes it locally.
  Future<bool> endPlot(String plotId) async {
    try {
      final existing = await _plotRepo.getById(plotId);
      if (existing == null) return false;

      final remoteId = existing.serverId ?? existing.id;
      try {
        await _api.updatePlot(remoteId, status: 'retired');
      } catch (e) {
        if (existing.serverId != null) {
          AppLogger.error('[DashboardCubit] endPlot remote failed: $e');
          emit(state.copyWith(errorMessage: e.toString()));
          return false;
        }
        // Local-only plot: remove offline without requiring server success.
        AppLogger.error(
          '[DashboardCubit] endPlot remote failed for local plot: $e',
        );
      }

      await _plotRepo.delete(plotId);
      AppLogger.request('[DashboardCubit] plot ended: $plotId');
      await _loadDashboard();
      return true;
    } catch (e) {
      AppLogger.error('[DashboardCubit] endPlot error: $e');
      emit(state.copyWith(errorMessage: e.toString()));
      return false;
    }
  }

  Future<void> triggerSync() async {
    if (state.isSyncing || !state.isOnline) return;

    AppLogger.request('[DashboardCubit] triggerSync started');
    emit(state.copyWith(syncJobStatus: SyncJobStatus.running));

    try {
      await _fieldSync.pullAndApply();
      await _loadDashboard();
      AppLogger.response('[DashboardCubit] triggerSync succeeded');
      emit(state.copyWith(syncJobStatus: SyncJobStatus.succeeded));
    } catch (e) {
      AppLogger.error('[DashboardCubit] triggerSync failed: $e');
      emit(
        state.copyWith(
          syncJobStatus: SyncJobStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    try {
      final results = await Future.wait([
        _plotRepo.getAssignedPlots(), // 0
        _plotRepo.getPlotCount(), // 1
        _plotRepo.getTotalTreeCount(), // 2
        _plotRepo.getInspectionDueCount(), // 3
        _treeRepo.getRegisteredTodayCount(), // 4
        _syncRepo.getPendingCount(), // 5
        _syncRepo.getFailedCount(), // 6
        _syncRepo.getLastSyncTime(), // 7
        _workerRepo.getWorkerCount(), // 8
        _workerRepo.getActiveCountToday(), // 9
        _workerRepo.getWorkersWithTodayStats(), // 10
        _taskRepo.getPendingCount(), // 11
      ]);

      // Show top 3 workers on the dashboard.
      final allWorkers = results[10] as List<WorkerTodayStats>;
      final topWorkers = allWorkers.take(3).toList();

      emit(
        state.copyWith(
          isLoading: false,
          plots: results[0] as List<PlotModel>,
          assignedPlots: results[1] as int,
          totalTrees: results[2] as int,
          inspectionsDue: results[3] as int,
          treesRegisteredToday: results[4] as int,
          pendingSync: results[5] as int,
          failedSync: results[6] as int,
          lastSyncTime: results[7] as DateTime?,
          workerCount: results[8] as int,
          activeWorkersToday: results[9] as int,
          topWorkers: topWorkers,
          pendingTasksCount: results[11] as int,
        ),
      );
    } catch (e) {
      AppLogger.error('[DashboardCubit] _loadDashboard error: $e');
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }
}
