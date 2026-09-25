import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/data/repositories/worker_plot_repository.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';
import 'package:mess_app/data/models/sync_record_model.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:uuid/uuid.dart';

import 'workers_state.dart';

/// Drives the Workers tab — full worker list with today's activity,
/// search, adding new workers, and toggling active status.
class WorkersCubit extends Cubit<WorkersState> {
  WorkersCubit({
    required WorkerRepository workerRepository,
    required WorkerPlotRepository workerPlotRepository,
    required SyncRepository syncRepository,
    required FieldApiService fieldApi,
  })  : _workerRepo = workerRepository,
        _plotRepo = workerPlotRepository,
        _syncRepo = syncRepository,
        _api = fieldApi,
        super(const WorkersInitial()) {
    load();
  }

  final WorkerRepository _workerRepo;
  final WorkerPlotRepository _plotRepo;
  final SyncRepository _syncRepo;
  final FieldApiService _api;
  final _uuid = const Uuid();

  Future<void> load() async {
    emit(const WorkersLoading());
    try {
      final stats = await _workerRepo.getWorkersWithTodayStats();
      emit(WorkersLoaded(workers: stats));
    } catch (e) {
      AppLogger.error('[WorkersCubit] load error: $e');
      emit(WorkersError(e.toString()));
    }
  }

  void search(String query) {
    final current = state;
    if (current is WorkersLoaded) {
      emit(current.copyWith(searchQuery: query));
    }
  }

  void clearSearch() {
    final current = state;
    if (current is WorkersLoaded) {
      emit(current.copyWith(searchQuery: ''));
    }
  }

  Future<bool> addWorker({
    required String name,
    String? phone,
    List<String> plotIds = const [],
  }) async {
    if (name.trim().isEmpty) return false;

    final current = state;
    emit(const WorkersSaving());

    try {
      String localId = _uuid.v4();
      var syncStatus = SyncStatus.pending;
      String? serverId;

      try {
        final remote = await _api.createWorker(
          name: name.trim(),
          phone: phone,
          plotIds: plotIds,
        );
        localId = (remote['id'] ?? localId).toString();
        serverId = localId;
        syncStatus = SyncStatus.synced;
      } catch (e) {
        AppLogger.error('[WorkersCubit] remote create failed, saving offline: $e');
      }

      final now = DateTime.now();
      final worker = WorkerModel(
        id: localId,
        serverId: serverId,
        name: name.trim(),
        phone: phone?.trim().isEmpty ?? true ? null : phone?.trim(),
        volunteerId: null,
        syncStatus: syncStatus,
        createdAt: now,
        updatedAt: now,
        syncedAt: syncStatus == SyncStatus.synced ? now : null,
      );

      await _workerRepo.upsert(worker);

      if (plotIds.isNotEmpty) {
        await _plotRepo.setAssignments(worker.id, plotIds);
        if (syncStatus == SyncStatus.synced) {
          try {
            await _api.setWorkerPlots(worker.id, plotIds);
          } catch (_) {}
        }
      }

      if (syncStatus == SyncStatus.pending) {
        await _syncRepo.enqueue(
          SyncRecordModel(
            id: _uuid.v4(),
            entityType: SyncEntityType.tree,
            entityId: worker.id,
            operation: SyncOperation.create,
            syncStatus: SyncStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      AppLogger.request('[WorkersCubit] worker added: ${worker.id}');
      await load();
      return true;
    } catch (e) {
      AppLogger.error('[WorkersCubit] addWorker error: $e');
      if (current is WorkersLoaded) emit(current);
      return false;
    }
  }

  Future<bool> updateWorker({
    required String workerId,
    required String name,
    String? phone,
    bool? isActive,
    List<String>? plotIds,
  }) async {
    if (name.trim().isEmpty) return false;

    final current = state;
    emit(const WorkersSaving());

    try {
      final existing = await _workerRepo.getById(workerId);
      if (existing == null) {
        if (current is WorkersLoaded) emit(current);
        return false;
      }

      final trimmedPhone =
          phone?.trim().isEmpty ?? true ? null : phone?.trim();
      final now = DateTime.now();
      var syncStatus = SyncStatus.pending;

      try {
        await _api.updateWorker(
          workerId,
          name: name.trim(),
          phone: trimmedPhone ?? '',
          isActive: isActive,
        );
        syncStatus = SyncStatus.synced;
      } catch (e) {
        AppLogger.error(
          '[WorkersCubit] remote update failed, saving offline: $e',
        );
      }

      final updated = existing.copyWith(
        name: name.trim(),
        phone: trimmedPhone,
        clearPhone: trimmedPhone == null,
        isActive: isActive,
        syncStatus: syncStatus,
        updatedAt: now,
        syncedAt: syncStatus == SyncStatus.synced ? now : null,
      );
      await _workerRepo.upsert(updated);

      if (plotIds != null) {
        await _plotRepo.setAssignments(workerId, plotIds);
        if (syncStatus == SyncStatus.synced) {
          try {
            await _api.setWorkerPlots(workerId, plotIds);
          } catch (e) {
            AppLogger.error(
              '[WorkersCubit] remote plot assign deferred: $e',
            );
          }
        }
      }

      if (syncStatus == SyncStatus.pending) {
        await _syncRepo.enqueue(
          SyncRecordModel(
            id: _uuid.v4(),
            entityType: SyncEntityType.tree,
            entityId: workerId,
            operation: SyncOperation.update,
            syncStatus: SyncStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      AppLogger.request('[WorkersCubit] worker updated: $workerId');
      await load();
      return true;
    } catch (e) {
      AppLogger.error('[WorkersCubit] updateWorker error: $e');
      if (current is WorkersLoaded) emit(current);
      return false;
    }
  }

  Future<bool> updateWorkerPlots(
    String workerId,
    List<String> plotIds,
  ) async {
    try {
      await _plotRepo.setAssignments(workerId, plotIds);
      try {
        await _api.setWorkerPlots(workerId, plotIds);
      } catch (e) {
        AppLogger.error('[WorkersCubit] remote plot assign deferred: $e');
      }
      await load();
      return true;
    } catch (e) {
      AppLogger.error('[WorkersCubit] updateWorkerPlots error: $e');
      return false;
    }
  }

  Future<void> toggleActiveStatus(String workerId, {required bool isActive}) async {
    try {
      await _workerRepo.setActiveStatus(workerId, isActive: isActive);
      try {
        await _api.updateWorker(workerId, isActive: isActive);
      } catch (e) {
        AppLogger.error('[WorkersCubit] remote toggle deferred: $e');
      }
      await load();
    } catch (e) {
      AppLogger.error('[WorkersCubit] toggleActiveStatus error: $e');
    }
  }
}
