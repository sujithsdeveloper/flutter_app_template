import 'package:dio/dio.dart';
import 'package:mess_app/core/constants/app_logger.dart';

class LoggerInterceptor extends Interceptor {
  static const _separator =
      '════════════════════════════════════════════════════════════';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.request('''
$_separator
🚀 REQUEST
$_separator
Method   : ${options.method}
URL      : ${options.uri}

Headers
${options.headers}

Query Params
${options.queryParameters}

Body
${options.data}

$_separator
''');

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.response('''
$_separator
✅ RESPONSE
$_separator
Status   : ${response.statusCode}
Method   : ${response.requestOptions.method}
URL      : ${response.requestOptions.uri}

Headers
${response.headers}

Data
${response.data}

$_separator
''');

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error('''
$_separator
❌ ERROR
$_separator
Method   : ${err.requestOptions.method}
URL      : ${err.requestOptions.uri}

Status   : ${err.response?.statusCode}
Type     : ${err.type}
Message  : ${err.message}

Response
${err.response?.data}

Error
${err.error}

$_separator
''');

    handler.next(err);
  }
}
