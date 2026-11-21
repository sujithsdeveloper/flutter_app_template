import 'rapid_tree_capture_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../trees/field_campaigns_screen.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/presentation/widgets/tree_photo_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

typedef _Row = Map<String, dynamic>;
const _datePattern = 'yyyy-MM-dd';

String? _reviewStatus(Map<String, dynamic> batch) =>
    switch (batch['reviewStatus']) {
      'pending' => 'Submitted for verification',
      'verified' => 'Verified',
      'rejected' => 'Review rejected',
      _ => null,
    };

class CorporatePlantationScreen extends StatefulWidget {
  const CorporatePlantationScreen({super.key, this.allocationId});

  final String? allocationId;

  @override
  State<CorporatePlantationScreen> createState() =>
      _CorporatePlantationScreenState();
}

class _CorporatePlantationScreenState extends State<CorporatePlantationScreen> {
  final _api = getIt<FieldApiService>();
  late final Future<(SharedPreferences, UserSession)> _account = _loadAccount();
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  List<_Row> _batches = [];
  int _pending = 0;
  int _pendingPhotos = 0;
  bool _loading = true;
  bool _syncing = false;
  String? _message;

  Future<(SharedPreferences, UserSession)> _loadAccount() async {
    final session = await getIt<SessionManager>().getSession();
    if (session == null || session.userId.isEmpty) {
      throw StateError('Sign in to view your planting batches.');
    }
    return (await SharedPreferences.getInstance(), session);
  }

  String _storageKey(UserSession session) =>
      'corporate-plantation.${session.role.value}.${session.userId}.';

  List<_Row> _decodeRows(String? data) => data == null
      ? []
      : (jsonDecode(data) as List).cast<Map<String, dynamic>>();

  List<_Row> _queuedPhotos(_Row draft) {
    final photos = draft['photos'] as List?;
    if (photos != null) return photos.cast<_Row>().toList();
    final legacy = draft['photo'] as String?;
    if (legacy == null || (draft['payload'] as Map)['photoUrl'] != null) {
      return [];
    }
    return [
      {'image': legacy, 'url': draft['uploadedPhotoUrl']},
    ];
  }

  void _countPending(SharedPreferences preferences, String prefix) {
    if (!mounted) return;
    var sessions = 0;
    var photos = 0;
    for (final key in preferences.getKeys()) {
      if (!key.startsWith('${prefix}draft.')) continue;
      final stored = preferences.getString(key);
      if (stored == null) continue;
      final draft = jsonDecode(stored) as _Row;
      if (draft['sessionId'] == null) {
        sessions++;
      } else {
        photos += _queuedPhotos(draft).length;
      }
    }
    setState(() {
      _pending = sessions;
      _pendingPhotos = photos;
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void dispose() {
    _connectivity?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_syncing || !mounted) return;
    setState(() {
      _syncing = true;
      _message = null;
    });
    try {
      final (preferences, session) = await _account;
      final prefix = _storageKey(session);
      final drafts =
          preferences
              .getKeys()
              .where((key) => key.startsWith('${prefix}draft.'))
              .toList()
            ..sort();
      if (mounted) {
        setState(
          () =>
              _batches = _decodeRows(preferences.getString('${prefix}batches')),
        );
      }
      _countPending(preferences, prefix);
      var saved = false;
      String? sessionError;
      String? photoError;
      for (final key in drafts) {
        final stored = preferences.getString(key);
        if (stored == null) continue;
        final draft = jsonDecode(stored) as _Row;
        final payload = Map<String, dynamic>.from(draft['payload'] as Map);
        var sessionId = draft['sessionId'] as String?;
        final photos = _queuedPhotos(draft);
        try {
          Future<String> upload(_Row photo) async {
            final existing = photo['url'] as String?;
            if (existing != null) return existing;
            final url = await _api.uploadPlantationPhoto(
              base64Decode(photo['image'] as String),
            );
            if (!preferences.containsKey(key)) return url;
            photo['url'] = url;
            draft['photos'] = photos;
            await preferences.setString(key, jsonEncode(draft));
            return url;
          }

          if (sessionId == null) {
            if (draft['requirePhoto'] == true && photos.isNotEmpty) {
              payload['photoUrl'] = await upload(photos.first);
              if (!preferences.containsKey(key)) continue;
            }
            sessionId = await _api.recordPlantationSession(
              draft['batchId'] as String,
              payload,
            );
            saved = true;
            if (!preferences.containsKey(key)) continue;
            draft['sessionId'] = sessionId;
            draft['photos'] = photos;
            await preferences.setString(key, jsonEncode(draft));
          }
          while (photos.isNotEmpty && preferences.containsKey(key)) {
            final photo = photos.first;
            final url = await upload(photo);
            if (!preferences.containsKey(key)) break;
            await _api.attachPlantationPhoto(
              sessionId,
              url,
              capturedAt: photo['capturedAt'] as String?,
            );
            if (!preferences.containsKey(key)) break;
            photos.removeAt(0);
            draft['photos'] = photos;
            await preferences.setString(key, jsonEncode(draft));
          }
          await preferences.remove(key);
        } catch (error) {
          final message = FieldApiService.messageOf(error);
          if (sessionId == null) {
            sessionError = message;
            if (FieldApiService.isOfflineError(error)) break;
          } else {
            photoError = message;
          }
        }
      }
      _countPending(preferences, prefix);
      if (saved) unawaited(_refreshTrees());
      final batches = await _api.listPlantationBatches();
      await preferences.setString('${prefix}batches', jsonEncode(batches));
      if (mounted) {
        setState(() {
          _batches = batches;
          _message = sessionError != null
              ? 'A session is still saved on this device. $sessionError'
              : photoError != null
              ? 'Planting saved. A photo is still waiting to upload. $photoError'
              : null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = FieldApiService.isOfflineError(error)
              ? 'Offline. Saved batches are available on this device.'
              : FieldApiService.messageOf(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _syncing = false;
        });
      }
    }
  }

  Future<void> _refreshTrees() async {
    try {
      await getIt<FieldSyncService>().pullAndApply();
    } catch (_) {
      // Tree data will refresh through the regular sync if this pull fails.
    }
  }

  Future<void> _open(_Row row) async {
    final (preferences, session) = await _account;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BatchDetail(
          initial: row,
          preferences: preferences,
          prefix: _storageKey(session),
          isFieldAdmin: session.role == UserRole.volunteer,
          sync: _refresh,
        ),
      ),
    );
    await _refresh();
  }

  bool _visibleBatch(_Row batch) =>
      widget.allocationId == null ||
      batch['allocationId'] == widget.allocationId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Corporate planting batches'),
      actions: [
        IconButton(
          tooltip: 'Refresh and send saved sessions',
          onPressed: _syncing ? null : _refresh,
          icon: const Icon(Icons.sync),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_syncing) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!),
            ),
          if (_pending > 0)
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text('$_pending planting sessions saved on this device'),
              subtitle: const Text('Refresh to retry syncing.'),
            ),
          if (_pendingPhotos > 0)
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(
                _pendingPhotos == 1
                    ? '1 planting photo pending'
                    : '$_pendingPhotos planting photos pending',
              ),
              subtitle: const Text(
                'Planting counts are synced. Refresh to retry the photos.',
              ),
            ),
          if (widget.allocationId == null)
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FieldCampaignsScreen(),
                  ),
                );
                await _refresh();
              },
              icon: const Icon(Icons.forest_outlined),
              label: const Text('Campaign allocations and progress'),
            ),
          if (!_loading && !_batches.any(_visibleBatch))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No corporate batches assigned to you.'),
            ),
          for (final batch in _batches.where(_visibleBatch))
            Card(
              child: ListTile(
                title: Text(batch['programName'] as String),
                subtitle: Text(
                  '${batch['companyName']} · ${batch['plot']} · ${batch['region']}\n'
                  '${batch['planted']} of ${batch['quantity']} planted'
                  '${_reviewStatus(batch) == null ? '' : '\n${_reviewStatus(batch)}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(batch),
              ),
            ),
        ],
      ),
    ),
  );
}

class _BatchDetail extends StatefulWidget {
  const _BatchDetail({
    required this.initial,
    required this.preferences,
    required this.prefix,
    required this.isFieldAdmin,
    required this.sync,
  });

  final _Row initial;
  final SharedPreferences preferences;
  final String prefix;
  final bool isFieldAdmin;
  final Future<void> Function() sync;

  @override
  State<_BatchDetail> createState() => _BatchDetailState();
}

class _BatchDetailState extends State<_BatchDetail> {
  final _api = getIt<FieldApiService>();
  late _Row _batch = widget.initial;
  List<_Row> _sessions = [];
  List<_Row> _volunteers = [];
  bool _busy = false;
  String? _error;

  String get _id => _batch['id'] as String;
  String get _sessionsKey => '${widget.prefix}sessions.$_id';
  int get _remaining =>
      (_batch['quantity'] as int) - (_batch['planted'] as int);
  bool get _open => _batch['canRecord'] == true && _remaining > 0;

  @override
  void initState() {
    super.initState();
    final saved = widget.preferences.getString(_sessionsKey);
    if (saved != null) _sessions = (jsonDecode(saved) as List).cast<_Row>();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final sessions = await _api.listPlantationSessions(_id);
      await widget.preferences.setString(_sessionsKey, jsonEncode(sessions));
      final batches = await _api.listPlantationBatches();
      final current = batches.where((item) => item['id'] == _id).firstOrNull;
      final workers = widget.isFieldAdmin ? await _api.listWorkers() : [];
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        if (current != null) _batch = current;
        _volunteers = workers.whereType<_Row>().where((worker) {
          final plots = worker['plotIds'];
          return worker['isActive'] == true &&
              plots is List &&
              plots.contains(_batch['plotId']);
        }).toList();
        _error = current == null
            ? 'This assignment is no longer available.'
            : null;
        if (current == null) _batch = {..._batch, 'canRecord': false};
      });
    } catch (error) {
      if (mounted) setState(() => _error = FieldApiService.messageOf(error));
    }
  }

  Future<void> _assign(String worker) async {
    setState(() => _busy = true);
    try {
      await _api.assignPlantationVolunteer(_id, worker);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = FieldApiService.messageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, _Row> _draftsForBatch() {
    final drafts = <String, _Row>{};
    for (final key in widget.preferences.getKeys()) {
      if (!key.startsWith('${widget.prefix}draft.')) continue;
      final stored = widget.preferences.getString(key);
      if (stored == null) continue;
      final draft = jsonDecode(stored) as _Row;
      if (draft['batchId'] == _id) drafts[key] = draft;
    }
    return drafts;
  }

  Future<void> _discardDraft(String key, {required bool photoOnly}) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          photoOnly ? 'Discard pending photo?' : 'Discard saved session?',
        ),
        content: Text(
          photoOnly
              ? 'The saved planting stays in the database.'
              : 'The unsynced session will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    await widget.preferences.remove(key);
    if (mounted) setState(() {});
  }

  Future<void> _record() async {
    final record = await showModalBottomSheet<_Row>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlantingForm(
        remaining: _remaining,
        requirePhoto: _batch['requireSessionPhoto'] == true,
      ),
    );
    if (record == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final payload = record['payload'] as _Row;
      final key =
          '${widget.prefix}draft.${DateTime.now().microsecondsSinceEpoch}.${payload['submissionKey']}';
      final saved = await widget.preferences.setString(
        key,
        jsonEncode({...record, 'batchId': _id}),
      );
      if (!saved) {
        throw StateError('Could not save the planting session on this device.');
      }
      await widget.sync();
      await _load();
      if (mounted) {
        final stored = widget.preferences.getString(key);
        final pending = stored != null ? jsonDecode(stored) as _Row : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pending == null
                  ? 'Planting session recorded.'
                  : pending['sessionId'] != null
                  ? 'Planting recorded. The photo will retry later.'
                  : 'Session saved on this device for sync.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = FieldApiService.messageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = _batch['quantity'] as int;
    final planted = _batch['planted'] as int;
    final workerId = _batch['workerId'] as String;
    final drafts = _draftsForBatch();
    return Scaffold(
      appBar: AppBar(title: const Text('Planting batch')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _batch['programName'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('${_batch['companyName']} · ${_batch['species']}'),
          const SizedBox(height: 8),
          Text('${_batch['plot']} · ${_batch['region']}'),
          Text('Field admin · ${_batch['fieldAdmin']}'),
          Text(
            'Status · ${_remaining == 0
                ? _reviewStatus(_batch) ?? 'Planting completed'
                : _open
                ? 'Open for planting'
                : 'Closed'}',
          ),
          if (_batch['reviewStatus'] == 'rejected' &&
              _batch['reviewNote'] is String)
            Text(_batch['reviewNote'] as String),
          if ((_batch['targetDate'] as String).isNotEmpty)
            Text('Target date · ${_batch['targetDate']}'),
          if (_batch['instructions'] != null)
            Text(_batch['instructions'] as String),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: planted / assigned),
          const SizedBox(height: 8),
          Text('$assigned assigned · $planted planted · $_remaining remaining'),
          const SizedBox(height: 12),
          if (widget.isFieldAdmin && _open && _volunteers.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey(workerId),
              initialValue:
                  _volunteers.any((worker) => worker['id'] == workerId)
                  ? workerId
                  : '',
              decoration: const InputDecoration(
                labelText: 'Assigned volunteer',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Field admin (self)'),
                ),
                for (final worker in _volunteers)
                  DropdownMenuItem(
                    value: worker['id'] as String,
                    child: Text(worker['name'] as String),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) unawaited(_assign(value));
                    },
            ),
          if ((_batch['verified'] as int? ?? 0) > 0 ||
              (_batch['verificationPending'] as int? ?? 0) > 0)
            Text(
              "${_batch['verified']} verified · ${_batch['verificationPending']} pending review",
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Rapid tree capture'),
            onPressed: _busy
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RapidTreeCaptureScreen(
                          batch: _batch,
                          account: widget.prefix,
                        ),
                      ),
                    );
                    if (mounted) await _load();
                  },
          ),
          if (_open &&
              drafts.values.every((draft) => draft['sessionId'] != null))
            FilledButton.icon(
              onPressed: _busy ? null : _record,
              icon: const Icon(Icons.add),
              label: const Text('Add planting session'),
            ),
          const SizedBox(height: 12),
          for (final draft in drafts.entries)
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(
                draft.value['sessionId'] != null
                    ? 'Planting recorded · Photo pending'
                    : "${draft.value['payload']['quantity']} trees saved for sync",
              ),
              subtitle: Text(draft.value['payload']['plantingDate'] as String),
              trailing: IconButton(
                tooltip: draft.value['sessionId'] != null
                    ? 'Discard pending photo'
                    : 'Discard saved session',
                onPressed: _busy
                    ? null
                    : () => _discardDraft(
                        draft.key,
                        photoOnly: draft.value['sessionId'] != null,
                      ),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          Text(
            'Planting sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_sessions.isEmpty) const Text('No synced planting sessions yet.'),
          for (final session in _sessions)
            Card(
              child: ListTile(
                title: Text(
                  '${session['quantity']} planted · ${session['plantingDate']}',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${session['planter']} · ${session['species']}'),
                    if (session['lat'] != null && session['lng'] != null)
                      Text('GPS ${session['lat']}, ${session['lng']}'),
                    if (session['notes'] != null)
                      Text(session['notes'] as String),
                    for (final photo in (session['photos'] as List? ?? []))
                      _SessionPhoto(
                        key: ValueKey(photo['url']),
                        path: photo['url'] as String,
                      ),
                    if (session['photos'] == null &&
                        session['photoUrl'] != null)
                      _SessionPhoto(path: session['photoUrl'] as String),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionPhoto extends StatefulWidget {
  const _SessionPhoto({super.key, required this.path});

  final String path;

  @override
  State<_SessionPhoto> createState() => _SessionPhotoState();
}

class _SessionPhotoState extends State<_SessionPhoto> {
  Future<List<int>>? _load;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(onPressed: _open, child: const Text('Retry photo'));
        }
        if (snapshot.hasData) {
          return Image.memory(Uint8List.fromList(snapshot.data!), height: 110);
        }
        if (_load != null) return const LinearProgressIndicator();
        return TextButton(onPressed: _open, child: const Text('View photo'));
      },
    );
  }

  void _open() {
    setState(
      () => _load = getIt<FieldApiService>().loadPlantationPhoto(widget.path),
    );
  }
}

class _PlantingForm extends StatefulWidget {
  const _PlantingForm({required this.remaining, required this.requirePhoto});
  final int remaining;
  final bool requirePhoto;

  @override
  State<_PlantingForm> createState() => _PlantingFormState();
}

class _PlantingFormState extends State<_PlantingForm> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  Position? _position;
  final List<_Row> _photos = [];
  String? _error;
  bool _locating = false;

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Allow location access to capture GPS.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not capture GPS. Check location permissions and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _capture() async {
    final path = await captureTreePhoto(
      context,
      AppText(LanguageController.language.value),
    );
    if (path == null) return;
    try {
      final bytes = await XFile(path).readAsBytes();
      if (!mounted) return;
      if (bytes.length > 2 * 1024 * 1024) {
        setState(() => _error = 'Capture a photo smaller than 2 MB.');
        return;
      }
      setState(() {
        _photos.add({
          'image': base64Encode(bytes),
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
        });
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read the captured photo.');
      }
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_position == null) {
      setState(() => _error = 'Capture the planting location first.');
      return;
    }
    if (widget.requirePhoto && _photos.isEmpty) {
      setState(() => _error = 'Take at least one planting session photo.');
      return;
    }
    Navigator.of(context).pop<_Row>({
      'payload': <String, dynamic>{
        'submissionKey': const Uuid().v4(),
        'quantity': int.parse(_quantity.text),
        'plantingDate': DateFormat(_datePattern).format(_date),
        'lat': _position!.latitude,
        'lng': _position!.longitude,
        'notes': _notes.text.trim(),
      },
      'photos': _photos,
      'requirePhoto': widget.requirePhoto,
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add planting session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              widget.requirePhoto
                  ? 'Take at least one photo of the planting session.'
                  : 'You can add photos of this planting session.',
            ),
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number planted (up to ${widget.remaining})',
              ),
              validator: (value) {
                final count = int.tryParse(value ?? '') ?? 0;
                return count < 1 || count > widget.remaining
                    ? 'Enter 1–${widget.remaining} trees.'
                    : null;
              },
            ),
            TextFormField(
              controller: _notes,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(DateFormat(_datePattern).format(_date)),
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (value != null && mounted) setState(() => _date = value);
              },
            ),
            OutlinedButton.icon(
              onPressed: _locating ? null : _locate,
              icon: const Icon(Icons.my_location),
              label: Text(
                _locating
                    ? 'Capturing GPS…'
                    : _position == null
                    ? 'Capture GPS'
                    : 'GPS captured',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _photos.length >= 5 ? null : _capture,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text('Take session photo (${_photos.length}/5)'),
            ),
            if (_photos.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final photo in _photos)
                    Stack(
                      children: [
                        Image.memory(
                          base64Decode(photo['image'] as String),
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                        ),
                        IconButton(
                          tooltip: 'Remove session photo',
                          icon: const Icon(Icons.cancel),
                          onPressed: () =>
                              setState(() => _photos.remove(photo)),
                        ),
                      ],
                    ),
                ],
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: _save,
              child: const Text('Save planting session'),
            ),
          ],
        ),
      ),
    ),
  );
}
