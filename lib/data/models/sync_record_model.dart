import 'package:mess_app/core/database/db_constants.dart';
import 'sync_status.dart';

/// The type of entity stored in the sync queue.
enum SyncEntityType {
  tree,
  inspection,
  photo;

  static SyncEntityType fromValue(String value) => switch (value) {
        'tree' => SyncEntityType.tree,
        'inspection' => SyncEntityType.inspection,
        'photo' => SyncEntityType.photo,
        _ => SyncEntityType.tree,
      };

  String get value => switch (this) {
        SyncEntityType.tree => 'tree',
        SyncEntityType.inspection => 'inspection',
        SyncEntityType.photo => 'photo',
      };
}

/// The operation that should be performed on the server.
enum SyncOperation {
  create,
  update;

  static SyncOperation fromValue(String value) => switch (value) {
        'create' => SyncOperation.create,
        'update' => SyncOperation.update,
        _ => SyncOperation.create,
      };

  String get value => switch (this) {
        SyncOperation.create => 'create',
        SyncOperation.update => 'update',
      };
}

/// An entry in the local sync outbox (sync_queue table). One record is created
/// per field operation (tree registration, inspection, photo upload) and
/// consumed by the sync engine when connectivity is available.
class SyncRecordModel {
  const SyncRecordModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payload,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;

  /// JSON snapshot of the entity at the time it was queued.
  final String? payload;

  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;

  // ── DB serialisation ─────────────────────────────────────────────────────

  factory SyncRecordModel.fromMap(Map<String, dynamic> map) {
    return SyncRecordModel(
      id: map[DbConstants.colId] as String,
      entityType: SyncEntityType.fromValue(
        map[DbConstants.colEntityType] as String,
      ),
      entityId: map[DbConstants.colEntityId] as String,
      operation: SyncOperation.fromValue(
        map[DbConstants.colOperation] as String,
      ),
      payload: map[DbConstants.colPayload] as String?,
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
      DbConstants.colEntityType: entityType.value,
      DbConstants.colEntityId: entityId,
      DbConstants.colOperation: operation.value,
      DbConstants.colPayload: payload,
      DbConstants.colSyncStatus: syncStatus.value,
      DbConstants.colRetryCount: retryCount,
      DbConstants.colLastError: lastError,
      DbConstants.colCreatedAt: createdAt.millisecondsSinceEpoch,
      DbConstants.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
      DbConstants.colSyncedAt: syncedAt?.millisecondsSinceEpoch,
    };
  }

  SyncRecordModel copyWith({
    SyncStatus? syncStatus,
    int? retryCount,
    String? lastError,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return SyncRecordModel(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
