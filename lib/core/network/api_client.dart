import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mess_app/core/network/app_interceptors.dart';
import 'package:mess_app/core/network/logger_interceptor.dart';

const _defaultBaseUrl = 'http://65.0.109.222:8990';

String resolveApiBaseUrl() {
  var base = (dotenv.env['BASE_URL'] ?? _defaultBaseUrl).trim();
  if (base.isEmpty) {
    base = _defaultBaseUrl;
  }

  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }

  // Api paths already include `/api/v1`, so strip it from the base if present.
  if (base.endsWith('/api/v1')) {
    base = base.substring(0, base.length - '/api/v1'.length);
  }

  return base;
}

class ApiClient {
  late final Dio dio;
  late final Dio refreshDio;

  ApiClient() {
    final baseOptions = BaseOptions(
      baseUrl: resolveApiBaseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    );

    dio = Dio(baseOptions);
    refreshDio = Dio(baseOptions);

    dio.interceptors.add(AppInterceptor(dio, refreshDio));
    dio.interceptors.add(LoggerInterceptor());
  }
}
