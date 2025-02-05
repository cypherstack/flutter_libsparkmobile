enum LoggingLevel { trace, debug, info, warning, error, fatal }

abstract class Log {
  static Set<LoggingLevel> levels = {
    LoggingLevel.warning,
    LoggingLevel.error,
    LoggingLevel.fatal,
  };

  static void Function(
    LoggingLevel level,
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    required DateTime time,
  })? onLog;

  static void l(
    LoggingLevel level,
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) {
    onLog?.call(
      level,
      value,
      error: error,
      stackTrace: stackTrace,
      time: time ?? DateTime.now(),
    );
  }

  static void t(
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) =>
      l(
        LoggingLevel.trace,
        value,
        error: error,
        stackTrace: stackTrace,
        time: time,
      );

  static void d(
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) =>
      l(
        LoggingLevel.debug,
        value,
        error: error,
        stackTrace: stackTrace,
        time: time,
      );

  static void i(
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) =>
      l(
        LoggingLevel.info,
        value,
        error: error,
        stackTrace: stackTrace,
        time: time,
      );

  static void w(
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) =>
      l(
        LoggingLevel.warning,
        value,
        error: error,
        stackTrace: stackTrace,
        time: time,
      );

  static void e(
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) =>
      l(
        LoggingLevel.error,
        value,
        error: error,
        stackTrace: stackTrace,
        time: time,
      );

  static void f(
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) =>
      l(
        LoggingLevel.fatal,
        value,
        error: error,
        stackTrace: stackTrace,
        time: time,
      );
}
