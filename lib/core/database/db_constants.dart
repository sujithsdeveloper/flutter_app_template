/// All table names, column names, and metadata keys used by the local SQLite
/// database. Centralising them here prevents typos and makes schema migrations
/// easier to track.
class DbConstants {
  DbConstants._();

  // ── DB meta ──────────────────────────────────────────────────────────────
  static const int version = 10;
  static const String dbName = 'omy_earth.db';

  // ── Table names ──────────────────────────────────────────────────────────
  static const String tablePlots = 'plots';
  static const String tableTrees = 'trees';
  static const String tableWorkers = 'workers';
  static const String tableWorkerPlotAssignments = 'worker_plot_assignments';
  static const String tableTreeTasks = 'tree_tasks';
  static const String tableInspections = 'inspections';
  static const String tableTreeGrowthUpdates = 'tree_growth_updates';
  static const String tablePhotos = 'photos';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableSyncMeta = 'sync_meta';

  // ── Shared columns (present in most tables) ──────────────────────────────
  static const String colId = 'id';
  static const String colServerId = 'server_id';
  static const String colSyncStatus = 'sync_status';
  static const String colRetryCount = 'retry_count';
  static const String colLastError = 'last_error';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colSyncedAt = 'synced_at';

  // ── plots columns ─────────────────────────────────────────────────────────
  static const String colName = 'name';
  static const String colLocation = 'location';
  static const String colDistrict = 'district';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colAreaHectares = 'area_hectares';
  static const String colTreeCount = 'tree_count';
  static const String colStatus = 'status';
  static const String colAssignedVolunteerId = 'assigned_volunteer_id';

  // ── workers columns ───────────────────────────────────────────────────────
  static const String colPhone = 'phone';
  static const String colPhotoPath = 'photo_path';
  static const String colVolunteerId = 'volunteer_id';
  static const String colIsActive = 'is_active';
  static const String colAssignedAt = 'assigned_at';

  // ── trees columns ─────────────────────────────────────────────────────────
  static const String colWorkerId = 'worker_id';
  static const String colSpecies = 'species';
  static const String colPlantingDate = 'planting_date';
  static const String colPlotId = 'plot_id';
  static const String colBatch = 'batch';
  static const String colSaplingSource = 'sapling_source';
  static const String colGpsAccuracy = 'gps_accuracy';
  static const String colNotes = 'notes';
  static const String colIsDead = 'is_dead';
  static const String colReplacementForId = 'replacement_for_id';

  // ── inspections columns ───────────────────────────────────────────────────
  static const String colTreeId = 'tree_id';
  static const String colGbhCm = 'gbh_cm';
  static const String colHeightM = 'height_m';
  static const String colSurvivalStatus = 'survival_status';
  static const String colHealthRating = 'health_rating';
  static const String colPestNotes = 'pest_notes';
  static const String colDiseaseNotes = 'disease_notes';
  static const String colInspectedAt = 'inspected_at';

  // ── photos columns ────────────────────────────────────────────────────────
  static const String colInspectionId = 'inspection_id';
  static const String colLocalPath = 'local_path';
  static const String colFileSizeBytes = 'file_size_bytes';
  static const String colTakenAt = 'taken_at';

  // ── sync_queue columns ────────────────────────────────────────────────────
  static const String colEntityType = 'entity_type';
  static const String colEntityId = 'entity_id';
  static const String colOperation = 'operation';
  static const String colPayload = 'payload';

  // ── tree_growth_updates columns ───────────────────────────────────────────
  static const String colGrowthStage = 'growth_stage';
  static const String colHeightCm = 'height_cm';
  static const String colRecordedBy = 'recorded_by';
  static const String colRecordedAt = 'recorded_at';

  // ── tree_tasks columns ────────────────────────────────────────────────────
  static const String colTaskStatus = 'task_status';
  static const String colAdminNotes = 'admin_notes';
  static const String colTargetDate = 'target_date';
  // Sponsored backend tree id (from GET /field/sync treeId).
  static const String colPlotName = 'plot_name';
  static const String colWorkerName = 'worker_name';
  static const String colRegionId = 'region_id';
  static const String colRegionName = 'region_name';
  static const String colSponsorshipId = 'sponsorship_id';
  static const String colSponsorIntent = 'sponsor_intent';

  // ── sync_meta keys ────────────────────────────────────────────────────────
  static const String metaKeyLastSyncTime = 'last_sync_time';
  static const String metaKeyVolunteerId = 'volunteer_id';

  // Auth credentials (seeded from admin panel / sync)
  static const String metaKeyAuthVolEmail = 'auth_vol_email';
  static const String metaKeyAuthVolPassword = 'auth_vol_password';
  static const String metaKeyAuthVolCode = 'auth_vol_code';
  static const String metaKeyAuthVolName = 'auth_vol_name';
  static const String metaKeyAuthVolId = 'auth_vol_id';

  // ── sync_meta columns ─────────────────────────────────────────────────────
  static const String colKey = 'key';
  static const String colValue = 'value';
}
