import 'package:mess_app/core/database/db_constants.dart';
import 'sync_status.dart';

/// Status of a sponsorship / admin planting task.
enum TaskStatus {
  /// Created from sponsorship (or admin), no worker assigned yet.
  pending,

  /// Volunteer assigned a worker; not yet planted.
  assigned,

  /// Tree has been planted and registered in the field.
  planted,

  /// Task cancelled by admin.
  cancelled;

  static TaskStatus fromValue(String v) {
    return switch (v) {
      'assigned' => assigned,
      'planted' => planted,
      'cancelled' => cancelled,
      _ => pending,
    };
  }

  String get value => switch (this) {
        pending => 'pending',
        assigned => 'assigned',
        planted => 'planted',
        cancelled => 'cancelled',
      };

  bool get isActionable => this == pending || this == assigned;
}

/// A tree planting task created from a sponsorship (or admin) for this
/// volunteer's region. Unassigned tasks have no [workerId] yet.
///
/// Volunteer admins assign a field worker in one step (backend auto-sets
/// volunteer_id). They do not claim tasks for themselves.
/// The worker plants at ([latitude], [longitude]).
class TreeTaskModel {
  const TreeTaskModel({
    required this.id,
    this.serverId,
    required this.plotId,
    this.plotName,
    required this.species,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.adminNotes,
    this.sponsorIntent,
    this.targetDate,
    this.volunteerId,
    this.workerId,
    this.workerName,
    this.photoPath,
    this.treeId,
    this.regionId,
    this.regionName,
    this.sponsorshipId,
    this.taskStatus = TaskStatus.pending,
    this.syncStatus = SyncStatus.synced,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  final String id;
  final String? serverId;
  final String plotId;
  final String? plotName;
  final String species;

  /// Target GPS latitude where the tree should be planted.
  final double latitude;

  /// Target GPS longitude where the tree should be planted.
  final double longitude;

  final String? notes;

  /// Instructions / sponsor copy about this planting.
  final String? adminNotes;

  /// Clear sponsor intent line, e.g. "A sponsor wants to plant this Teak in Wayanad".
  final String? sponsorIntent;

  final DateTime? targetDate;
  final String? volunteerId;

  /// The worker (planter) assigned to this task by the volunteer.
  final String? workerId;
  final String? workerName;

  /// Local path to the photo taken by the worker when planting.
  final String? photoPath;

  /// Backend sponsored tree id (same row donors see on My Trees).
  final String? treeId;

  final String? regionId;
  final String? regionName;
  final String? sponsorshipId;

  final TaskStatus taskStatus;
  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;

  /// Pending and still needs a field worker assigned.
  bool get needsAssignment =>
      taskStatus == TaskStatus.pending &&
      (workerId == null || workerId!.isEmpty);

  /// True when this task came from a donor sponsorship.
  bool get isSponsored =>
      (sponsorshipId != null && sponsorshipId!.isNotEmpty) ||
      (treeId != null && treeId!.isNotEmpty);

  /// Display line for sponsor intent (API field, notes fallback, or generated).
  String displaySponsorIntent(String Function(String species, String region) fallback) {
    final intent = sponsorIntent?.trim();
    if (intent != null && intent.isNotEmpty) return intent;
    final notesLine = adminNotes?.trim();
    if (notesLine != null && notesLine.isNotEmpty) return notesLine;
    final notesFallback = notes?.trim();
    if (notesFallback != null && notesFallback.isNotEmpty) return notesFallback;
    return fallback(species, regionName ?? '');
  }

  String get displayPlotLabel {
    final name = plotName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return plotId;
  }

  /// Compact tree id for list cards; keep full [treeId] on detail screens.
  String get displayTreeIdShort {
    final id = treeId?.trim();
    if (id == null || id.isEmpty) return '';
    for (final prefix in const ['tree-seed-', 'tree-']) {
      if (id.startsWith(prefix) && id.length > prefix.length) {
        return id.substring(prefix.length);
      }
    }
    final dash = id.lastIndexOf('-');
    if (dash > 0 && dash < id.length - 1) {
      return id.substring(dash + 1);
    }
    return id;
  }

  String get displayWorkerLabel {
    final name = workerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return workerId ?? '';
  }

  // ── DB serialisation ─────────────────────────────────────────────────────

  factory TreeTaskModel.fromMap(Map<String, dynamic> map) {
    return TreeTaskModel(
      id: map[DbConstants.colId] as String,
      serverId: map[DbConstants.colServerId] as String?,
      plotId: map[DbConstants.colPlotId] as String,
      plotName: map[DbConstants.colPlotName] as String?,
      species: map[DbConstants.colSpecies] as String,
      latitude: (map[DbConstants.colLatitude] as num).toDouble(),
      longitude: (map[DbConstants.colLongitude] as num).toDouble(),
      notes: map[DbConstants.colNotes] as String?,
      adminNotes: map[DbConstants.colAdminNotes] as String?,
      sponsorIntent: map[DbConstants.colSponsorIntent] as String?,
      targetDate: map[DbConstants.colTargetDate] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map[DbConstants.colTargetDate] as int,
            )
          : null,
      volunteerId: map[DbConstants.colVolunteerId] as String?,
      workerId: map[DbConstants.colWorkerId] as String?,
      workerName: map[DbConstants.colWorkerName] as String?,
      photoPath: map[DbConstants.colPhotoPath] as String?,
      treeId: map[DbConstants.colTreeId] as String?,
      regionId: map[DbConstants.colRegionId] as String?,
      regionName: map[DbConstants.colRegionName] as String?,
      sponsorshipId: map[DbConstants.colSponsorshipId] as String?,
      taskStatus: TaskStatus.fromValue(
        (map[DbConstants.colTaskStatus] as String?) ?? 'pending',
      ),
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
      DbConstants.colPlotId: plotId,
      DbConstants.colPlotName: plotName,
      DbConstants.colSpecies: species,
      DbConstants.colLatitude: latitude,
      DbConstants.colLongitude: longitude,
      DbConstants.colNotes: notes,
      DbConstants.colAdminNotes: adminNotes,
      DbConstants.colSponsorIntent: sponsorIntent,
      DbConstants.colTargetDate: targetDate?.millisecondsSinceEpoch,
      DbConstants.colVolunteerId: volunteerId,
      DbConstants.colWorkerId: workerId,
      DbConstants.colWorkerName: workerName,
      DbConstants.colPhotoPath: photoPath,
      DbConstants.colTreeId: treeId,
      DbConstants.colRegionId: regionId,
      DbConstants.colRegionName: regionName,
      DbConstants.colSponsorshipId: sponsorshipId,
      DbConstants.colTaskStatus: taskStatus.value,
      DbConstants.colSyncStatus: syncStatus.value,
      DbConstants.colRetryCount: retryCount,
      DbConstants.colLastError: lastError,
      DbConstants.colCreatedAt: createdAt.millisecondsSinceEpoch,
      DbConstants.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
      DbConstants.colSyncedAt: syncedAt?.millisecondsSinceEpoch,
    };
  }

  TreeTaskModel copyWith({
    String? volunteerId,
    String? workerId,
    String? workerName,
    String? photoPath,
    String? notes,
    String? treeId,
    String? regionId,
    String? regionName,
    String? plotName,
    String? sponsorIntent,
    TaskStatus? taskStatus,
    SyncStatus? syncStatus,
    int? retryCount,
    String? lastError,
    DateTime? updatedAt,
  }) {
    return TreeTaskModel(
      id: id,
      serverId: serverId,
      plotId: plotId,
      plotName: plotName ?? this.plotName,
      species: species,
      latitude: latitude,
      longitude: longitude,
      notes: notes ?? this.notes,
      adminNotes: adminNotes,
      sponsorIntent: sponsorIntent ?? this.sponsorIntent,
      targetDate: targetDate,
      volunteerId: volunteerId ?? this.volunteerId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      photoPath: photoPath ?? this.photoPath,
      treeId: treeId ?? this.treeId,
      regionId: regionId ?? this.regionId,
      regionName: regionName ?? this.regionName,
      sponsorshipId: sponsorshipId,
      taskStatus: taskStatus ?? this.taskStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt,
    );
  }

  /// Human-readable GPS string for display.
  String get locationLabel {
    final lat = latitude.toStringAsFixed(4);
    final lon = longitude.toStringAsFixed(4);
    return '$lat, $lon';
  }

  /// True when a target date exists and it is today or in the past.
  bool get isDue {
    if (targetDate == null) return false;
    final today = DateTime.now();
    return targetDate!.isBefore(
      DateTime(today.year, today.month, today.day + 1),
    );
  }
}
