import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';
import 'package:mess_app/data/repositories/worker_plot_repository.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';
import 'package:mess_app/presentation/blocs/connectivity/connectivity_cubit.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_cubit.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';

class Providers {
  static List<BlocProvider> get providers => [
    BlocProvider<ConnectivityCubit>(create: (_) => ConnectivityCubit()),
    BlocProvider<DashboardCubit>(
      create: (_) => DashboardCubit(
        plotRepository: getIt<PlotRepository>(),
        treeRepository: getIt<TreeRepository>(),
        syncRepository: getIt<SyncRepository>(),
        workerRepository: getIt<WorkerRepository>(),
        taskRepository: getIt<TreeTaskRepository>(),
        fieldSyncService: getIt<FieldSyncService>(),
        fieldApi: getIt<FieldApiService>(),
      ),
    ),
    BlocProvider<WorkersCubit>(
      create: (_) => WorkersCubit(
        workerRepository: getIt<WorkerRepository>(),
        workerPlotRepository: getIt<WorkerPlotRepository>(),
        syncRepository: getIt<SyncRepository>(),
        fieldApi: getIt<FieldApiService>(),
      ),
    ),
    BlocProvider<TreeTasksCubit>(
      create: (_) => TreeTasksCubit(
        taskRepository: getIt<TreeTaskRepository>(),
        fieldApi: getIt<FieldApiService>(),
        fieldSync: getIt<FieldSyncService>(),
      ),
    ),
  ];
}
