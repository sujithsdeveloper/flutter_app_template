import 'package:mess_app/core/database/db_constants.dart';
import 'sync_status.dart';

/// A tree registered by a field volunteer. The [id] is a client-generated UUID
/// that uniquely identifies the record even before it reaches the server.
class TreeModel {
  const TreeModel({
    required this.id,
    this.serverId,
    this.species,
    this.plantingDate,
    required this.plotId,
    this.batch,
    this.saplingSource,
    required this.latitude,
    required this.longitude,
    this.gpsAccuracy,
    this.notes,
    this.workerId,
    this.isDead = false,
    this.replacementForId,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  final String id;
  final String? serverId;
  final String? species;
  final DateTime? plantingDate;
  final String plotId;
  final String? batch;
  final String? saplingSource;
  final double latitude;
  final double longitude;
  final double? gpsAccuracy;
  final String? notes;
  final String? workerId;
  final bool isDead;
  final String? replacementForId;
  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;

  // ── DB serialisation ─────────────────────────────────────────────────────

  factory TreeModel.fromMap(Map<String, dynamic> map) {
    return TreeModel(
      id: map[DbConstants.colId] as String,
      serverId: map[DbConstants.colServerId] as String?,
      species: map[DbConstants.colSpecies] as String?,
      plantingDate: map[DbConstants.colPlantingDate] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map[DbConstants.colPlantingDate] as int,
            )
          : null,
      plotId: map[DbConstants.colPlotId] as String,
      batch: map[DbConstants.colBatch] as String?,
      saplingSource: map[DbConstants.colSaplingSource] as String?,
      latitude: map[DbConstants.colLatitude] as double,
      longitude: map[DbConstants.colLongitude] as double,
      gpsAccuracy: map[DbConstants.colGpsAccuracy] as double?,
      notes: map[DbConstants.colNotes] as String?,
      workerId: map[DbConstants.colWorkerId] as String?,
      isDead: ((map[DbConstants.colIsDead] as int?) ?? 0) == 1,
      replacementForId: map[DbConstants.colReplacementForId] as String?,
      syncStatus: SyncStatus.fromValue(
        (map[DbConstants.colSyncStatus] as String?) ?? 'pending',
      ),
      retryCount: (map[DbConstants.colRetryCount] as int?) ?? 0,
      lastError: map[DbConstants.colLastError] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map[DbConstants.colCreatedAt] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map[DbConstants.colUpdatedAt] as int,
      ),
      syncedAt: map[DbConstants.colSyncedAt] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map[DbConstants.colSyncedAt] as int,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colServerId: serverId,
      DbConstants.colSpecies: species,
      DbConstants.colPlantingDate: plantingDate?.millisecondsSinceEpoch,
      DbConstants.colPlotId: plotId,
      DbConstants.colBatch: batch,
      DbConstants.colSaplingSource: saplingSource,
      DbConstants.colLatitude: latitude,
      DbConstants.colLongitude: longitude,
      DbConstants.colGpsAccuracy: gpsAccuracy,
      DbConstants.colNotes: notes,
      DbConstants.colWorkerId: workerId,
      DbConstants.colIsDead: isDead ? 1 : 0,
      DbConstants.colReplacementForId: replacementForId,
      DbConstants.colSyncStatus: syncStatus.value,
      DbConstants.colRetryCount: retryCount,
      DbConstants.colLastError: lastError,
      DbConstants.colCreatedAt: createdAt.millisecondsSinceEpoch,
      DbConstants.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
      DbConstants.colSyncedAt: syncedAt?.millisecondsSinceEpoch,
    };
  }

  TreeModel copyWith({
    String? serverId,
    SyncStatus? syncStatus,
    int? retryCount,
    String? lastError,
    bool? isDead,
    String? replacementForId,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return TreeModel(
      id: id,
      serverId: serverId ?? this.serverId,
      species: species,
      plantingDate: plantingDate,
      plotId: plotId,
      batch: batch,
      saplingSource: saplingSource,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      notes: notes,
      isDead: isDead ?? this.isDead,
      replacementForId: replacementForId ?? this.replacementForId,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
