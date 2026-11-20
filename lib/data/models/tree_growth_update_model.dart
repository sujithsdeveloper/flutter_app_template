import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/sync_status.dart';

/// The life-cycle stage of a planted tree, updated by the worker over time.
enum GrowthStage {
  /// Tree has just been planted — the initial state.
  planted,

  /// Visible sprouts / first leaves emerging.
  sprouting,

  /// Active healthy growth.
  growing,

  /// Fully established; minimal attention required.
  established,

  /// Shows signs of stress, disease, or pest damage.
  needsAttention,

  /// Tree has died.
  dead;

  static GrowthStage fromValue(String v) => switch (v) {
    'sprouting' => sprouting,
    'growing' => growing,
    'established' => established,
    'needs_attention' => needsAttention,
    'dead' => dead,
    _ => planted,
  };

  String get value => switch (this) {
    planted => 'planted',
    sprouting => 'sprouting',
    growing => 'growing',
    established => 'established',
    needsAttention => 'needs_attention',
    dead => 'dead',
  };
}

/// A single growth-stage entry recorded by a worker for one of their trees.
class TreeGrowthUpdateModel {
  const TreeGrowthUpdateModel({
    required this.id,
    required this.treeId,
    required this.stage,
    this.heightCm,
    this.notes,
    this.photoPath,
    this.recordedBy,
    this.recordedByName,
    required this.recordedAt,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String treeId;
  final GrowthStage stage;
  final double? heightCm;
  final String? notes;
  final String? photoPath;

  /// Worker ID who recorded this update.
  final String? recordedBy;
  final String? recordedByName;

  final DateTime recordedAt;
  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TreeGrowthUpdateModel.fromApi(Map<String, dynamic> map) {
    final recordedAt = DateTime.parse(map['recordedAt'] as String);
    final photoUrl = map['photoUrl'] as String?;
    return TreeGrowthUpdateModel(
      id: map['id'] as String,
      treeId: map['treeId'] as String,
      stage: GrowthStage.fromValue(map['stage'] as String),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      photoPath: photoUrl == null || photoUrl.isEmpty ? null : photoUrl,
      recordedBy: map['recordedBy'] as String?,
      recordedByName: map['recordedByName'] as String?,
      recordedAt: recordedAt,
      syncStatus: SyncStatus.synced,
      createdAt: recordedAt,
      updatedAt: recordedAt,
    );
  }

  factory TreeGrowthUpdateModel.fromMap(Map<String, dynamic> map) {
    return TreeGrowthUpdateModel(
      id: map[DbConstants.colId] as String,
      treeId: map[DbConstants.colTreeId] as String,
      stage: GrowthStage.fromValue(
        (map[DbConstants.colGrowthStage] as String?) ?? 'planted',
      ),
      heightCm: (map[DbConstants.colHeightCm] as num?)?.toDouble(),
      notes: map[DbConstants.colNotes] as String?,
      photoPath: map[DbConstants.colPhotoPath] as String?,
      recordedBy: map[DbConstants.colRecordedBy] as String?,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        map[DbConstants.colRecordedAt] as int,
      ),
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colTreeId: treeId,
      DbConstants.colGrowthStage: stage.value,
      DbConstants.colHeightCm: heightCm,
      DbConstants.colNotes: notes,
      DbConstants.colPhotoPath: photoPath,
      DbConstants.colRecordedBy: recordedBy,
      DbConstants.colRecordedAt: recordedAt.millisecondsSinceEpoch,
      DbConstants.colSyncStatus: syncStatus.value,
      DbConstants.colRetryCount: retryCount,
      DbConstants.colLastError: lastError,
      DbConstants.colCreatedAt: createdAt.millisecondsSinceEpoch,
      DbConstants.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
    };
  }
}
