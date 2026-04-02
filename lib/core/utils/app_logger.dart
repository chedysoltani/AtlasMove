import 'dart:developer' as developer;

class AppLogger {
  static void debug(String message, {String? tag}) {
    if (AppConstants.enableLogging) {
      developer.log(
        'DEBUG: $message',
        name: tag ?? 'App',
      );
    }
  }

  static void info(String message, {String? tag}) {
    if (AppConstants.enableLogging) {
      developer.log(
        'INFO: $message',
        name: tag ?? 'App',
      );
    }
  }

  static void warning(String message, {String? tag}) {
    if (AppConstants.enableLogging) {
      developer.log(
        'WARNING: $message',
        name: tag ?? 'App',
      );
    }
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConstants.enableLogging) {
      developer.log(
        'ERROR: $message',
        name: tag ?? 'App',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
