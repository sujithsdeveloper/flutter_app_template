import 'package:dio/dio.dart';
import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/network/api_client.dart';
import 'package:mess_app/core/network/api_urls.dart';

/// Thin Dio wrapper for OmyEarth field APIs. Callers handle offline fallback.
class FieldApiService {
  FieldApiService({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  Future<Map<String, dynamic>> volunteerLogin({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      ApiUrls.volunteerLogin,
      data: {'email': email.trim(), 'password': password},
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> workerLogin({
    required String phone,
    required String code,
  }) async {
    final res = await _dio.post(
      ApiUrls.workerLogin,
      data: {'phone': phone.trim(), 'code': code.trim()},
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> fieldSync() async {
    final res = await _dio.get(
      ApiUrls.fieldSync,
      queryParameters: {'includeBulkTrees': 'false'},
    );
    return _unwrap(res);
  }

  /// Resolves the current bearer token to a profile (`GET /auth/me`).
  Future<Map<String, dynamic>> authMe() async {
    final res = await _dio.get(ApiUrls.authMe);
    return Map<String, dynamic>.from(_unwrap(res) as Map? ?? {});
  }

  Future<List<dynamic>> listWorkers() async {
    final res = await _dio.get(ApiUrls.workers);
    final data = _unwrap(res);
    if (data is List) return data;
    return const [];
  }

  Future<Map<String, dynamic>> createWorker({
    required String name,
    String? phone,
    List<String> plotIds = const [],
  }) async {
    final res = await _dio.post(
      ApiUrls.workers,
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'plotIds': plotIds,
      },
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> updateWorker(
    String id, {
    String? name,
    String? phone,
    bool? isActive,
  }) async {
    final res = await _dio.patch(
      ApiUrls.workerById(id),
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (isActive != null) 'isActive': isActive,
      },
    );
    return _unwrap(res);
  }

  Future<void> setWorkerPlots(String id, List<String> plotIds) async {
    await _dio.put(ApiUrls.workerPlots(id), data: {'plotIds': plotIds});
  }

  static const _plantationBatches = '/api/v1/field/plantation-batches';

  Future<List<Map<String, dynamic>>> listPlantationAllocations() async {
    final res = await _dio.get('/api/v1/field/plantation-allocations');
    return (_unwrap(res) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listPlantationSpecies() async {
    final res = await _dio.get('/api/v1/species');
    return (_unwrap(res) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> batchTrees(
    String batchId,
    int page, {
    String verification = '',
  }) async {
    final res = await _dio.get(
      '$_plantationBatches/$batchId/trees',
      queryParameters: {
        'page': page,
        if (verification.isNotEmpty) 'verification': verification,
      },
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> fieldTreeDetails(String treeId) async {
    final res = await _dio.get('/api/v1/field/trees/$treeId');
    return _unwrap(res);
  }

  Future<void> savePlantationAllocation(
    String programId,
    Map<String, dynamic> fields,
  ) async {
    await _dio.put(
      '/api/v1/field/plantations/$programId/allocations',
      data: fields,
    );
  }

  Future<void> createPlantationBatch(
    String programId,
    Map<String, dynamic> fields,
  ) async {
    await _dio.post(
      '/api/v1/field/plantations/$programId/batches',
      data: fields,
    );
  }

  Future<String> saveRapidRun(
    String id,
    String batchId,
    String startedAt, {
    String? state,
  }) async {
    final response = await _dio.put(
      '/api/v1/field/rapid-runs/$id',
      data: {
        'batchId': batchId,
        'startedAt': startedAt,
        if (state != null) 'state': state,
      },
    );
    return _unwrap(response)['state'] as String;
  }

  Future<void> recordRapidTree(
    String sessionId,
    Map<String, dynamic> capture,
  ) async {
    await _dio.post('/api/v1/field/rapid-runs/$sessionId/trees', data: capture);
  }

  Future<void> uploadTreeEvidence(
    String treeId,
    String mediaId,
    List<int> bytes, {
    required String capturedAt,
    required String kind,
    String? notes,
  }) async {
    await _dio.post(
      '/api/v1/field/trees/$treeId/evidence/$mediaId',
      data: FormData.fromMap({
        'kind': kind,
        'capturedAt': capturedAt,
        if (notes != null) 'notes': notes,
        'file': MultipartFile.fromBytes(bytes, filename: 'capture.jpg'),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> verifyPlanting(String treeId, bool verified) async {
    await _dio.put(
      '/api/v1/field/trees/$treeId/verification',
      data: {'verified': verified},
    );
  }

  Future<List<Map<String, dynamic>>> treeEvidence(String treeId) async {
    final response = await _dio.get('/api/v1/field/trees/$treeId/evidence');
    return (_unwrap(response) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listPlantationBatches() async {
    final response = await _dio.get(_plantationBatches);
    return (_unwrap(response) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listPlantationSessions(
    String batchId,
  ) async {
    final response = await _dio.get('$_plantationBatches/$batchId/sessions');
    return (_unwrap(response) as List).cast<Map<String, dynamic>>();
  }

  Future<void> assignPlantationVolunteer(
    String batchId,
    String workerId,
  ) async {
    await _dio.patch(
      '$_plantationBatches/$batchId/worker',
      data: {'workerId': workerId},
    );
  }

  Future<void> updatePlantationBatch(
    String batchId, {
    required int quantity,
    required String targetDate,
  }) async {
    await _dio.patch(
      '$_plantationBatches/$batchId/worker',
      data: {'quantity': quantity, 'targetDate': targetDate},
    );
  }

  Future<String> recordPlantationSession(
    String batchId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(
      '$_plantationBatches/$batchId/sessions',
      data: data,
    );
    return _unwrap(response)['id'] as String;
  }

  Future<void> attachPlantationPhoto(
    String sessionId,
    String photoUrl, {
    String? capturedAt,
  }) async {
    await _dio.put(
      '/api/v1/field/plantation-sessions/$sessionId/photo',
      data: {
        'photoUrl': photoUrl,
        if (capturedAt != null) 'capturedAt': capturedAt,
      },
    );
  }

  Future<String> uploadPlantationPhoto(List<int> bytes) =>
      _uploadPhoto('/api/v1/field/plantation-photos', bytes);

  Future<String> uploadGrowthPhoto(List<int> bytes) =>
      _uploadPhoto('/api/v1/field/growth-photos', bytes);

  Future<String> _uploadPhoto(String endpoint, List<int> bytes) async {
    final response = await _dio.post(
      endpoint,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'planting.jpg'),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
    return _unwrap(response)['objectUrl'] as String;
  }

  Future<List<int>> loadPlantationPhoto(String url) async {
    if (!url.startsWith('/api/v1/media/plantation_photo/') &&
        !url.startsWith('/api/v1/media/growth_photo/') &&
        !url.startsWith('/api/v1/media/tree_evidence/')) {
      throw StateError('Invalid photo address.');
    }
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const [];
  }

  Future<List<dynamic>> listTreeTasks() async {
    final res = await _dio.get(ApiUrls.treeTasks);
    final data = _unwrap(res);
    if (data is List) return data;
    return const [];
  }

  Future<Map<String, dynamic>> claimTreeTask(String id) async {
    final res = await _dio.post('${ApiUrls.treeTaskById(id)}/claim');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> recordPersonalPlantingSession(
    String taskId,
    Map<String, dynamic> payload,
  ) async {
    final result = await _dio.post(
      '/api/v1/tree-tasks/$taskId/planting-sessions',
      data: payload,
    );
    return Map<String, dynamic>.from(_unwrap(result) as Map);
  }

  Future<Map<String, dynamic>> updateTreeTask(
    String id, {
    String? workerId,
    String? taskStatus,
    String? notes,
    String? photoUrl,
    double? lat,
    double? lng,
  }) async {
    final res = await _dio.patch(
      ApiUrls.treeTaskById(id),
      data: {
        if (workerId != null) 'workerId': workerId,
        if (taskStatus != null) 'taskStatus': taskStatus,
        if (notes != null) 'notes': notes,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return _unwrap(res);
  }

  Future<List<Map<String, dynamic>>> listGrowthUpdates(String treeId) async {
    final res = await _dio.get(ApiUrls.treeGrowth(treeId));
    final updates = _unwrap(res) as List;
    return updates
        .map((update) => Map<String, dynamic>.from(update as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createGrowthUpdate({
    required String treeId,
    required String stage,
    double? heightCm,
    String? notes,
    String? photoUrl,
    String? recordedBy,
  }) async {
    final res = await _dio.post(
      ApiUrls.treeGrowth(treeId),
      data: {
        'stage': stage,
        if (heightCm != null) 'heightCm': heightCm,
        if (notes != null) 'notes': notes,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (recordedBy != null) 'recordedBy': recordedBy,
      },
    );
    return _unwrap(res);
  }

  /// Deprecated for volunteers — plot create is staff-only via web admin.
  /// Kept so callers fail loudly if invoked; server also returns 403.
  Future<Map<String, dynamic>> createPlot({
    required String name,
    required String location,
    String? district,
    double? latitude,
    double? longitude,
    double? areaAcres,
    String? assignedVolunteerId,
  }) async {
    throw UnsupportedError(
      'Plot creation is only available from the web admin panel',
    );
  }

  Future<Map<String, dynamic>> updatePlot(
    String id, {
    String? name,
    String? location,
    String? district,
    double? latitude,
    double? longitude,
    double? areaAcres,
    String? status,
  }) async {
    final res = await _dio.patch(
      ApiUrls.fieldPlotById(id),
      data: {
        if (name != null) 'name': name.trim(),
        if (location != null) 'location': location.trim(),
        if (district != null) 'district': district,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (areaAcres != null) 'areaAcres': areaAcres,
        if (status != null) 'status': status,
        if (latitude != null && longitude != null)
          'geoBoundary': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      },
    );
    return _unwrap(res);
  }

  dynamic _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  /// Returns true when [error] looks like a network / unreachable failure.
  static bool isOfflineError(Object error) {
    if (error is! DioException) return false;
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown;
  }

  static String messageOf(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        final msg = (data['error'] as Map)['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      if (isOfflineError(error)) {
        return 'Could not reach the server. Working offline.';
      }
      return error.message ?? 'Request failed';
    }
    AppLogger.error('[FieldApiService] $error');
    return error.toString();
  }
}
