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
    final res = await _dio.get(ApiUrls.fieldSync);
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
    await _dio.put(
      ApiUrls.workerPlots(id),
      data: {'plotIds': plotIds},
    );
  }

  Future<List<dynamic>> listTreeTasks() async {
    final res = await _dio.get(ApiUrls.treeTasks);
    final data = _unwrap(res);
    if (data is List) return data;
    return const [];
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
