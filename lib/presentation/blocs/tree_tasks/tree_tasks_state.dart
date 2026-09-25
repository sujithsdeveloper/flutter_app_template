import 'package:equatable/equatable.dart';
import 'package:mess_app/data/models/tree_task_model.dart';

sealed class TreeTasksState extends Equatable {
  const TreeTasksState();
}

final class TreeTasksInitial extends TreeTasksState {
  const TreeTasksInitial();
  @override
  List<Object?> get props => [];
}

final class TreeTasksLoading extends TreeTasksState {
  const TreeTasksLoading();
  @override
  List<Object?> get props => [];
}

final class TreeTasksLoaded extends TreeTasksState {
  const TreeTasksLoaded({
    required this.tasks,
    this.activeFilter,
  });

  final List<TreeTaskModel> tasks;

  /// Active filter tab. Null means "All".
  final TaskStatus? activeFilter;

  List<TreeTaskModel> get filtered {
    if (activeFilter == null) return tasks;
    return tasks.where((t) => t.taskStatus == activeFilter).toList();
  }

  int get pendingCount =>
      tasks.where((t) => t.taskStatus == TaskStatus.pending).length;

  int get assignedCount =>
      tasks.where((t) => t.taskStatus == TaskStatus.assigned).length;

  int get plantedCount =>
      tasks.where((t) => t.taskStatus == TaskStatus.planted).length;

  TreeTasksLoaded copyWith({
    List<TreeTaskModel>? tasks,
    TaskStatus? activeFilter,
    bool clearFilter = false,
  }) {
    return TreeTasksLoaded(
      tasks: tasks ?? this.tasks,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
    );
  }

  @override
  List<Object?> get props => [tasks, activeFilter];
}

final class TreeTaskAssigning extends TreeTasksState {
  const TreeTaskAssigning(this.taskId);
  final String taskId;
  @override
  List<Object?> get props => [taskId];
}

final class TreeTasksError extends TreeTasksState {
  const TreeTasksError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
