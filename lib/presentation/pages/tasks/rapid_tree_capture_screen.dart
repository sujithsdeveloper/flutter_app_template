import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/data/repositories/rapid_capture_repository.dart';
import 'package:mess_app/presentation/widgets/tree_photo_capture.dart';
import 'package:uuid/uuid.dart';

class RapidTreeCaptureScreen extends StatefulWidget {
  const RapidTreeCaptureScreen({
    super.key,
    required this.batch,
    required this.account,
  });

  final Map<String, dynamic> batch;
  final String account;

  @override
  State<RapidTreeCaptureScreen> createState() => _RapidTreeCaptureScreenState();
}

class _RapidTreeCaptureScreenState extends State<RapidTreeCaptureScreen> {
  final _repo = RapidCaptureRepository(getIt<AppDatabase>());
  final _api = getIt<FieldApiService>();
  final _notes = TextEditingController();
  late final String _batchId = widget.batch['id'] as String;
  late int _planted = widget.batch['planted'] as int;
  late bool _canRecord = widget.batch['canRecord'] == true;
  late int _target = widget.batch['quantity'] as int;
  RapidRow? _run;
  List<RapidRow> _trees = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _loading = true;
  bool _capturing = false;
  bool _syncing = false;
  bool _syncAgain = false;
  String? _message;
  int _pending = 0;
  int _photos = 0;
  String get _state => _run?['state'] as String? ?? '';
  String get _runId => _run!['id'] as String;
  int get _remaining => (_target - _planted - _pending).clamp(0, _target);

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
    _connectivity = Connectivity().onConnectivityChanged.listen((states) {
      if (states.any((state) => state != ConnectivityResult.none)) {
        unawaited(_sync());
      }
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    _connectivity?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _reload();
      unawaited(_sync());
    } catch (error) {
      if (mounted) setState(() => _message = FieldApiService.messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final run = await _repo.latestRun(widget.account, _batchId);
    final trees = run == null
        ? <RapidRow>[]
        : await _repo.trees(run['id'] as String);
    final (pending, photos) = await _repo.pendingCounts(
      widget.account,
      _batchId,
    );
    if (!mounted) return;
    setState(() {
      _run = run;
      _trees = trees;
      _pending = pending;
      _photos = photos;
    });
  }

  Future<void> _start() async {
    if (_capturing || _syncing) return;
    setState(() => _capturing = true);
    try {
      await _repo.addRun(
        widget.account,
        _batchId,
        const Uuid().v4(),
        DateTime.now().toUtc().toIso8601String(),
      );
      await _reload();
      unawaited(_sync());
    } catch (error) {
      if (mounted) setState(() => _message = FieldApiService.messageOf(error));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _change(String state) async {
    await _repo.changeState(_runId, state);
    await _reload();
    unawaited(_sync());
  }

  Future<Position?> _location() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _capture() async {
    if (_capturing || _state != 'active' || _remaining < 1) return;
    setState(() {
      _capturing = true;
      _message = null;
    });
    try {
      final path = await captureTreePhoto(
        context,
        AppText(LanguageController.language.value),
      );
      if (path == null || !mounted) return;
      final capturedAt = DateTime.now().toUtc().toIso8601String();
      final photo = await XFile(path).readAsBytes();
      if (photo.isEmpty || photo.length > 2 * 1024 * 1024) {
        if (mounted) {
          setState(
            () => _message =
                'This photo could not be saved under the 2 MB limit. Retake it.',
          );
        }
        return;
      }
      final position = await _location();
      if (!mounted) return;
      await _repo.addTree(_runId, {
        'id': const Uuid().v4(),
        'captured_at': capturedAt,
        'lat': position?.latitude,
        'lng': position?.longitude,
        'notes': _notes.text.trim(),
      }, photo);
      _notes.clear();
      await _reload();
      unawaited(_sync());
    } catch (error) {
      if (mounted) setState(() => _message = FieldApiService.messageOf(error));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _syncRun(RapidRow run) async {
    final runId = run['id'] as String;
    final startedAt = run['started_at'] as String;
    final serverState = await _api.saveRapidRun(runId, _batchId, startedAt);
    final rows = await _repo.trees(runId);
    final notSynced = rows.where((row) => row['tree_synced'] == 0);
    if (notSynced.isNotEmpty && serverState == 'paused') {
      await _api.saveRapidRun(runId, _batchId, startedAt, state: 'active');
    }
    for (final row in notSynced) {
      final id = row['id'] as String;
      await _api.recordRapidTree(runId, {
        'treeId': id,
        'capturedAt': row['captured_at'],
        'lat': row['lat'],
        'lng': row['lng'],
        'notes': row['notes'],
      });
      await _repo.markTreeSynced(id);
      if (mounted) setState(() => _planted++);
    }
    final desired = await _repo.runState(runId);
    final current = await _repo.trees(runId);
    if (current.every((row) => row['tree_synced'] == 1) &&
        !(mounted && _capturing && _runId == runId)) {
      final status = await _api.saveRapidRun(
        runId,
        _batchId,
        startedAt,
        state: desired,
      );
      if (status == 'finished') await _repo.markFinishedSynced(runId);
    }
  }

  Future<void> _syncPhotos(String runId) async {
    final rows = await _repo.trees(runId);
    for (final row in rows.where(
      (row) => row['photo_synced'] == 0 && row['tree_synced'] == 1,
    )) {
      final id = row['id'] as String;
      final photo = await _repo.photo(id);
      if (photo == null) continue;
      await _api.uploadTreeEvidence(
        id,
        id,
        photo,
        capturedAt: row['captured_at'] as String,
        kind: 'initial_planting',
      );
      await _repo.markPhotoSynced(id);
    }
  }

  Future<void> _sync() async {
    if (_run == null || !mounted) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    setState(() => _syncing = true);
    String? errorMessage;
    try {
      final runs = await _repo.runsToSync(widget.account, _batchId);
      for (final run in runs) {
        await _syncRun(run);
      }
      final batches = await _api.listPlantationBatches();
      final current = batches
          .where((batch) => batch['id'] == _batchId)
          .firstOrNull;
      if (mounted && current != null) {
        setState(() {
          _planted = current['planted'] as int;
          _target = current['quantity'] as int;
          _canRecord = current['canRecord'] == true;
        });
      }
      // Refresh the counts before uploading photos so a slow image does not
      // hold up the next capture or hide a server-accepted planting.
      await _reload();
      for (final run in runs) {
        try {
          await _syncPhotos(run['id'] as String);
        } catch (error) {
          errorMessage =
              'Tree saved. Photo waiting to upload. ${FieldApiService.messageOf(error)}';
          break;
        }
      }
    } catch (error) {
      errorMessage = FieldApiService.isOfflineError(error)
          ? 'Offline. Captures are saved on this device.'
          : FieldApiService.messageOf(error);
    } finally {
      if (mounted) {
        await _reload();
        if (mounted) {
          setState(() {
            _syncing = false;
            _message = errorMessage;
          });
        }
      }
      if (_syncAgain && mounted) {
        _syncAgain = false;
        unawaited(_sync());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final captured = _planted + _pending;
    final photos = _photos;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapid tree capture'),
        actions: [
          IconButton(
            onPressed: _syncing || _run == null ? null : _sync,
            icon: const Icon(Icons.sync),
            tooltip: 'Sync captured trees',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.batch['programName'] as String,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  [
                    widget.batch['companyName'],
                    widget.batch['region'],
                    widget.batch['plot'],
                  ].whereType<String>().join(' · '),
                ),
                Text('Species · ${widget.batch['species']}'),
                const SizedBox(height: 12),
                Text(
                  '$_target target · $captured captured in batch · $_remaining remaining',
                ),
                LinearProgressIndicator(
                  value: _target == 0
                      ? 0
                      : (captured / _target).clamp(0.0, 1.0),
                ),
                const SizedBox(height: 8),
                if (_run != null)
                  Text(
                    'Session ${_state == 'active' ? 'in progress' : _state} · ${_trees.length} trees captured',
                  ),
                if (_state == 'finished' && _run?['server_finished'] == 0)
                  const Text('Session finish waiting to sync.'),
                if (_syncing) const Text('Syncing captures…'),
                if (_pending > 0 || photos > 0)
                  Text('$_pending trees and $photos photos awaiting sync'),
                if (_message != null) Text(_message!),
                const SizedBox(height: 12),
                if (_state == 'active' && _canRecord && _remaining > 0) ...[
                  TextField(
                    controller: _notes,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Notes for next tree (optional)',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _capturing ? null : _capture,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_capturing ? 'Capturing…' : 'Capture tree'),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  children: [
                    if ((_state.isEmpty || _state == 'finished') &&
                        _canRecord &&
                        _remaining > 0)
                      FilledButton(
                        onPressed: _capturing || _syncing ? null : _start,
                        child: const Text('Start planting session'),
                      ),
                    if (_state == 'active')
                      OutlinedButton(
                        onPressed: _capturing ? null : () => _change('paused'),
                        child: const Text('Pause'),
                      ),
                    if (_state == 'paused' && _canRecord)
                      OutlinedButton(
                        onPressed: _capturing ? null : () => _change('active'),
                        child: const Text('Resume'),
                      ),
                    if (_state == 'active' || _state == 'paused')
                      OutlinedButton(
                        onPressed: _capturing
                            ? null
                            : () => _change('finished'),
                        child: const Text('Finish session'),
                      ),
                  ],
                ),
                if (_trees.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recently captured',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final tree in _trees.reversed.take(12))
                    Card(
                      child: ListTile(
                        title: Text(
                          "TR-${tree['id']}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          [
                            tree['lat'] == null
                                ? 'GPS unavailable'
                                : 'GPS captured',
                            tree['tree_synced'] == 1
                                ? 'Tree synced'
                                : 'Tree saved locally',
                            tree['photo_synced'] == 1
                                ? 'Photo synced'
                                : 'Photo queued',
                          ].join(' · '),
                        ),
                        leading: const Icon(Icons.park_outlined),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
