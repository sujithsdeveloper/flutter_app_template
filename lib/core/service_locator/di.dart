import 'package:get_it/get_it.dart';
import 'package:mess_app/core/auth/auth_service.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/constants/token_manager.dart';
import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/network/api_client.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/data/repositories/tree_growth_repository.dart';
import 'package:mess_app/data/repositories/tree_task_repository.dart';
import 'package:mess_app/data/repositories/worker_plot_repository.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';

final getIt = GetIt.instance;

class DependencyInjection {
  static void setupDependencyInjection() {
    // ── Infrastructure ─────────────────────────────────────────────────────
    getIt.registerLazySingleton<ApiClient>(() => ApiClient());
    getIt.registerLazySingleton<TokenManager>(() => TokenManager());
    getIt.registerLazySingleton<FieldApiService>(
      () => FieldApiService(apiClient: getIt<ApiClient>()),
    );

    // AppDatabase is initialised in main() before this call.
    getIt.registerSingleton<AppDatabase>(AppDatabase.instance);

    // ── Repositories ───────────────────────────────────────────────────────
    getIt.registerLazySingleton<PlotRepository>(
      () => PlotRepository(db: getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<TreeRepository>(
      () => TreeRepository(db: getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<SyncRepository>(
      () => SyncRepository(db: getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<WorkerPlotRepository>(
      () => WorkerPlotRepository(db: getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<WorkerRepository>(
      () => WorkerRepository(db: getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<TreeTaskRepository>(
      () => TreeTaskRepository(db: getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<TreeGrowthRepository>(
      () => TreeGrowthRepository(db: getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<FieldSyncService>(
      () => FieldSyncService(
        api: getIt<FieldApiService>(),
        plotRepository: getIt<PlotRepository>(),
        workerRepository: getIt<WorkerRepository>(),
        workerPlotRepository: getIt<WorkerPlotRepository>(),
        taskRepository: getIt<TreeTaskRepository>(),
        syncRepository: getIt<SyncRepository>(),
      ),
    );

    // ── Auth ───────────────────────────────────────────────────────────────
    getIt.registerLazySingleton<SessionManager>(() => SessionManager());
    getIt.registerLazySingleton<AuthService>(
      () => AuthService(
        syncRepository: getIt<SyncRepository>(),
        workerRepository: getIt<WorkerRepository>(),
        sessionManager: getIt<SessionManager>(),
        fieldApi: getIt<FieldApiService>(),
        fieldSync: getIt<FieldSyncService>(),
      ),
    );
  }
}
