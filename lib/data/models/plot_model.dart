import 'package:mess_app/core/database/db_constants.dart';
import 'sync_status.dart';

/// Visual health state of a plot, derived from field inspection data.
enum PlotStatus {
  healthy,
  needsCheck,
  inspectionDue;

  static PlotStatus fromValue(String value) => switch (value) {
        'healthy' => PlotStatus.healthy,
        'needs_check' => PlotStatus.needsCheck,
        'inspection_due' => PlotStatus.inspectionDue,
        _ => PlotStatus.healthy,
      };

  String get value => switch (this) {
        PlotStatus.healthy => 'healthy',
        PlotStatus.needsCheck => 'needs_check',
        PlotStatus.inspectionDue => 'inspection_due',
      };
}

/// Immutable model representing a land plot assigned to a field volunteer.
class PlotModel {
  const PlotModel({
    required this.id,
    this.serverId,
    required this.name,
    required this.location,
    this.district,
    this.latitude,
    this.longitude,
    this.areaHectares,
    this.treeCount = 0,
    this.status = PlotStatus.healthy,
    this.assignedVolunteerId,
    this.syncStatus = SyncStatus.synced,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  final String id;
  final String? serverId;
  final String name;
  final String location;
  final String? district;
  final double? latitude;
  final double? longitude;
  final double? areaHectares;
  final int treeCount;
  final PlotStatus status;
  final String? assignedVolunteerId;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;

  // ── DB serialisation ─────────────────────────────────────────────────────

  factory PlotModel.fromMap(Map<String, dynamic> map) {
    return PlotModel(
      id: map[DbConstants.colId] as String,
      serverId: map[DbConstants.colServerId] as String?,
      name: map[DbConstants.colName] as String,
      location: map[DbConstants.colLocation] as String,
      district: map[DbConstants.colDistrict] as String?,
      latitude: map[DbConstants.colLatitude] as double?,
      longitude: map[DbConstants.colLongitude] as double?,
      areaHectares: map[DbConstants.colAreaHectares] as double?,
      treeCount: (map[DbConstants.colTreeCount] as int?) ?? 0,
      status: PlotStatus.fromValue(
        (map[DbConstants.colStatus] as String?) ?? 'healthy',
      ),
      assignedVolunteerId:
          map[DbConstants.colAssignedVolunteerId] as String?,
      syncStatus: SyncStatus.fromValue(
        (map[DbConstants.colSyncStatus] as String?) ?? 'synced',
      ),
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
      DbConstants.colLocation: location,
      DbConstants.colDistrict: district,
      DbConstants.colLatitude: latitude,
      DbConstants.colLongitude: longitude,
      DbConstants.colAreaHectares: areaHectares,
      DbConstants.colTreeCount: treeCount,
      DbConstants.colStatus: status.value,
      DbConstants.colAssignedVolunteerId: assignedVolunteerId,
      DbConstants.colSyncStatus: syncStatus.value,
      DbConstants.colCreatedAt: createdAt.millisecondsSinceEpoch,
      DbConstants.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
      DbConstants.colSyncedAt: syncedAt?.millisecondsSinceEpoch,
    };
  }

  PlotModel copyWith({
    String? name,
    String? location,
    String? district,
    double? latitude,
    double? longitude,
    double? areaHectares,
    int? treeCount,
    PlotStatus? status,
    String? assignedVolunteerId,
    SyncStatus? syncStatus,
    String? serverId,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool clearDistrict = false,
    bool clearLatitude = false,
    bool clearLongitude = false,
    bool clearAreaHectares = false,
  }) {
    return PlotModel(
      id: id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      location: location ?? this.location,
      district: clearDistrict ? null : (district ?? this.district),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      areaHectares:
          clearAreaHectares ? null : (areaHectares ?? this.areaHectares),
      treeCount: treeCount ?? this.treeCount,
      status: status ?? this.status,
      assignedVolunteerId: assignedVolunteerId ?? this.assignedVolunteerId,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
