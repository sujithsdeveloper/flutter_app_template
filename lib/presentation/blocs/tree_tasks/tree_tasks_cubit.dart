import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';

import 'tree_tasks_state.dart';

/// Drives the Tasks tab — admin-assigned planting tasks, filter tabs, and
/// the volunteer→worker assignment flow.
class TreeTasksCubit extends Cubit<TreeTasksState> {
  TreeTasksCubit({
    required TreeTaskRepository taskRepository,
    required FieldApiService fieldApi,
    required FieldSyncService fieldSync,
  })  : _repo = taskRepository,
        _api = fieldApi,
        _fieldSync = fieldSync,
        super(const TreeTasksInitial()) {
    load();
  }

  final TreeTaskRepository _repo;
  final FieldApiService _api;
  final FieldSyncService _fieldSync;

  Future<void> load({TaskStatus? filter}) async {
    final previous = state;
    emit(const TreeTasksLoading());
    try {
      final tasks = await _repo.getAll();
      emit(
        TreeTasksLoaded(
          tasks: tasks,
          activeFilter: previous is TreeTasksLoaded
              ? filter ?? previous.activeFilter
              : filter,
        ),
      );
    } catch (e) {
      AppLogger.error('[TreeTasksCubit] load error: $e');
      emit(TreeTasksError(e.toString()));
    }
  }

  /// Pulls region + assigned tasks from the API into SQLite, then reloads UI.
  Future<void> syncAndLoad() async {
    try {
      await _fieldSync.pullAndApply();
    } catch (e) {
      AppLogger.error('[TreeTasksCubit] syncAndLoad remote failed: $e');
    }
    await load();
  }

  void setFilter(TaskStatus? status) {
    final current = state;
    if (current is TreeTasksLoaded) {
      emit(current.copyWith(
        activeFilter: status,
        clearFilter: status == null,
      ));
    }
  }

  Future<TreeTaskModel> claimForSelf(String taskId) async {
    final response = await _api.claimTreeTask(taskId);
    final task = await _fieldSync.cacheTask(response);
    await load();
    return task;
  }

  Future<TreeTaskModel?> assignWorker(
    String taskId,
    String workerId, {
    String? workerName,
  }) async {
    AppLogger.request(
      '[TreeTasksCubit] assigning worker $workerId → task $taskId',
    );
    TreeTaskModel? updated;
    try {
      final response = await _api.updateTreeTask(
        taskId,
        workerId: workerId,
        taskStatus: 'assigned',
      );
      updated = await _fieldSync.cacheTask(response);
    } catch (e) {
      if (!FieldApiService.isOfflineError(e)) rethrow;
      AppLogger.error('[TreeTasksCubit] remote assign deferred: $e');
      updated = await _repo.assignWorker(
        taskId,
        workerId,
        workerName: workerName,
      );
    }
    await load();
    return updated;
  }

  Future<void> unassignWorker(String taskId) async {
    try {
      await _repo.unassignWorker(taskId);
      try {
        await _api.updateTreeTask(taskId, workerId: '', taskStatus: 'pending');
      } catch (e) {
        AppLogger.error('[TreeTasksCubit] remote unassign deferred: $e');
      }
      await load();
    } catch (e) {
      AppLogger.error('[TreeTasksCubit] unassignWorker error: $e');
    }
  }
}
