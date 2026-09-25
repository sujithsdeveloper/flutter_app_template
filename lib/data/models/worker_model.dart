import 'package:mess_app/core/database/db_constants.dart';
import 'sync_status.dart';

/// A field volunteer (non-privileged) managed by a privileged volunteer.
class WorkerModel {
  const WorkerModel({
    required this.id,
    this.serverId,
    required this.name,
    this.phone,
    this.photoPath,
    this.volunteerId,
    this.isActive = true,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  final String id;
  final String? serverId;
  final String name;
  final String? phone;
  final String? photoPath;
  final String? volunteerId;
  final bool isActive;
  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;

  /// Two-letter initials used for the avatar circle.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  // ── DB serialisation ─────────────────────────────────────────────────────

  factory WorkerModel.fromMap(Map<String, dynamic> map) {
    return WorkerModel(
      id: map[DbConstants.colId] as String,
      serverId: map[DbConstants.colServerId] as String?,
      name: map[DbConstants.colName] as String,
      phone: map[DbConstants.colPhone] as String?,
      photoPath: map[DbConstants.colPhotoPath] as String?,
      volunteerId: map[DbConstants.colVolunteerId] as String?,
      isActive: ((map[DbConstants.colIsActive] as int?) ?? 1) == 1,
      syncStatus: SyncStatus.fromValue(
        (map[DbConstants.colSyncStatus] as String?) ?? 'synced',
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
      DbConstants.colName: name,
      DbConstants.colPhone: phone,
      DbConstants.colPhotoPath: photoPath,
      DbConstants.colVolunteerId: volunteerId,
      DbConstants.colIsActive: isActive ? 1 : 0,
      DbConstants.colSyncStatus: syncStatus.value,
      DbConstants.colRetryCount: retryCount,
      DbConstants.colLastError: lastError,
      DbConstants.colCreatedAt: createdAt.millisecondsSinceEpoch,
      DbConstants.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
      DbConstants.colSyncedAt: syncedAt?.millisecondsSinceEpoch,
    };
  }

  WorkerModel copyWith({
    String? name,
    String? phone,
    bool clearPhone = false,
    bool? isActive,
    SyncStatus? syncStatus,
    int? retryCount,
    String? lastError,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return WorkerModel(
      id: id,
      serverId: serverId,
      name: name ?? this.name,
      phone: clearPhone ? null : (phone ?? this.phone),
      photoPath: photoPath,
      volunteerId: volunteerId,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

/// Combines a [WorkerModel] with their aggregated activity for today,
/// computed by a single JOIN query in [WorkerRepository].
class WorkerTodayStats {
  const WorkerTodayStats({
    required this.worker,
    required this.treesToday,
    this.lastActivity,
    this.assignedPlotCount = 0,
    this.assignedPlotSummary,
  });

  final WorkerModel worker;

  /// Number of trees this worker registered today (local device date).
  final int treesToday;

  /// Timestamp of the most recent tree registered today (null if none).
  final DateTime? lastActivity;

  /// Plots assigned to this volunteer by the admin volunteer.
  final int assignedPlotCount;

  /// Comma-separated plot names for list previews.
  final String? assignedPlotSummary;

  bool get activatedToday => treesToday > 0;
}
