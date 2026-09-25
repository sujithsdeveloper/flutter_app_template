import 'package:equatable/equatable.dart';
import 'package:mess_app/data/models/worker_model.dart';

sealed class WorkersState extends Equatable {
  const WorkersState();
}

final class WorkersInitial extends WorkersState {
  const WorkersInitial();
  @override
  List<Object?> get props => [];
}

final class WorkersLoading extends WorkersState {
  const WorkersLoading();
  @override
  List<Object?> get props => [];
}

final class WorkersLoaded extends WorkersState {
  const WorkersLoaded({
    required this.workers,
    this.searchQuery = '',
  });

  final List<WorkerTodayStats> workers;
  final String searchQuery;

  List<WorkerTodayStats> get filtered {
    if (searchQuery.isEmpty) return workers;
    final q = searchQuery.toLowerCase();
    return workers.where((s) {
      return s.worker.name.toLowerCase().contains(q) ||
          (s.worker.phone?.contains(q) ?? false);
    }).toList();
  }

  int get totalCount => workers.length;

  int get activeToday => workers.where((s) => s.treesToday > 0).length;

  WorkersLoaded copyWith({
    List<WorkerTodayStats>? workers,
    String? searchQuery,
  }) {
    return WorkersLoaded(
      workers: workers ?? this.workers,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [workers, searchQuery];
}

final class WorkersSaving extends WorkersState {
  const WorkersSaving();
  @override
  List<Object?> get props => [];
}

final class WorkersError extends WorkersState {
  const WorkersError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
