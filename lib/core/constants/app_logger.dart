import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _requestLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: 120,
      colors: false,
      printEmojis: true,
      printTime: true,
    ),
  );

  static final Logger _responseLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: 120,
      colors: false,
      printEmojis: true,
      printTime: true,
    ),
  );

  static final Logger _errorLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,

      printEmojis: true,
      printTime: true,
    ),
  );

  static void request(String msg) {
    _requestLogger.i(msg);
  }

  static void response(String msg) {
    _responseLogger.d(msg);
  }

  static void error(String msg) {
    _errorLogger.e(msg);
  }

  static void refresh(String msg) {
    _errorLogger.w(msg);
  }
}
