/// Per-record sync state shared by trees, inspections, photos and the
/// sync_queue table. The `conflict` value is set when the server rejects an
/// upload because it already has a newer version of the same record.
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
  conflict;

  static SyncStatus fromValue(String value) => switch (value) {
        'pending' => SyncStatus.pending,
        'syncing' => SyncStatus.syncing,
        'synced' => SyncStatus.synced,
        'failed' => SyncStatus.failed,
        'conflict' => SyncStatus.conflict,
        _ => SyncStatus.pending,
      };

  String get value => switch (this) {
        SyncStatus.pending => 'pending',
        SyncStatus.syncing => 'syncing',
        SyncStatus.synced => 'synced',
        SyncStatus.failed => 'failed',
        SyncStatus.conflict => 'conflict',
      };
}
