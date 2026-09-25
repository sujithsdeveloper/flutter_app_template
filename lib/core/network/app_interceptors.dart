import 'package:dio/dio.dart';
import 'package:mess_app/core/constants/token_manager.dart';

class AppInterceptor extends Interceptor {
  final Dio dio;
  final Dio refreshDio;

  final refreshManager = TokenRefreshManager();

  AppInterceptor(this.dio, this.refreshDio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenManager.getAccessToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Field JWTs are long-lived single tokens (no refresh endpoint). Surface
    // 401s directly so callers can fall back to offline behaviour.
    handler.next(err);
  }
}
