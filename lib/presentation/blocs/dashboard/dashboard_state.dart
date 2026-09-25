import 'package:equatable/equatable.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/worker_model.dart';

enum SyncJobStatus { idle, running, succeeded, failed }

/// Immutable state produced by [DashboardCubit].
class DashboardState extends Equatable {
  const DashboardState({
    required this.isLoading,
    required this.isOnline,
    required this.assignedPlots,
    required this.totalTrees,
    required this.treesRegisteredToday,
    required this.inspectionsDue,
    required this.pendingSync,
    required this.failedSync,
    required this.lastSyncTime,
    required this.syncJobStatus,
    required this.plots,
    required this.workerCount,
    required this.activeWorkersToday,
    required this.topWorkers,
    required this.pendingTasksCount,
    this.errorMessage,
  });

  factory DashboardState.initial() => const DashboardState(
        isLoading: true,
        isOnline: false,
        assignedPlots: 0,
        totalTrees: 0,
        treesRegisteredToday: 0,
        inspectionsDue: 0,
        pendingSync: 0,
        failedSync: 0,
        lastSyncTime: null,
        syncJobStatus: SyncJobStatus.idle,
        plots: [],
        workerCount: 0,
        activeWorkersToday: 0,
        topWorkers: [],
        pendingTasksCount: 0,
        errorMessage: null,
      );

  final bool isLoading;
  final bool isOnline;
  final int assignedPlots;
  final int totalTrees;
  final int treesRegisteredToday;
  final int inspectionsDue;
  final int pendingSync;
  final int failedSync;
  final DateTime? lastSyncTime;
  final SyncJobStatus syncJobStatus;
  final List<PlotModel> plots;

  /// Total active workers under this volunteer.
  final int workerCount;

  /// Workers who planted at least one tree today.
  final int activeWorkersToday;

  /// Top workers by today's activity (up to 3), shown on the home dashboard.
  final List<WorkerTodayStats> topWorkers;

  /// Tree planting tasks assigned by admin that have no worker yet.
  final int pendingTasksCount;

  final String? errorMessage;

  bool get isSyncing => syncJobStatus == SyncJobStatus.running;

  DashboardState copyWith({
    bool? isLoading,
    bool? isOnline,
    int? assignedPlots,
    int? totalTrees,
    int? treesRegisteredToday,
    int? inspectionsDue,
    int? pendingSync,
    int? failedSync,
    DateTime? lastSyncTime,
    SyncJobStatus? syncJobStatus,
    List<PlotModel>? plots,
    int? workerCount,
    int? activeWorkersToday,
    List<WorkerTodayStats>? topWorkers,
    int? pendingTasksCount,
    String? errorMessage,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      isOnline: isOnline ?? this.isOnline,
      assignedPlots: assignedPlots ?? this.assignedPlots,
      totalTrees: totalTrees ?? this.totalTrees,
      treesRegisteredToday: treesRegisteredToday ?? this.treesRegisteredToday,
      inspectionsDue: inspectionsDue ?? this.inspectionsDue,
      pendingSync: pendingSync ?? this.pendingSync,
      failedSync: failedSync ?? this.failedSync,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncJobStatus: syncJobStatus ?? this.syncJobStatus,
      plots: plots ?? this.plots,
      workerCount: workerCount ?? this.workerCount,
      activeWorkersToday: activeWorkersToday ?? this.activeWorkersToday,
      topWorkers: topWorkers ?? this.topWorkers,
      pendingTasksCount: pendingTasksCount ?? this.pendingTasksCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isOnline,
        assignedPlots,
        totalTrees,
        treesRegisteredToday,
        inspectionsDue,
        pendingSync,
        failedSync,
        lastSyncTime,
        syncJobStatus,
        plots,
        workerCount,
        activeWorkersToday,
        topWorkers,
        pendingTasksCount,
        errorMessage,
      ];
}
