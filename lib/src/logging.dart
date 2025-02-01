enum LoggingLevel { trace, debug, info, warning, error, fatal }

final _reg = RegExp("[A-Za-z0-9]");
const _space = " ";

extension ST on StackTrace {
  String get functionName {
    final stackTraceString = toString();
    final str = stackTraceString.substring(stackTraceString.indexOf(_space));
    final index = str.indexOf(_reg);
    return str.substring(index).substring(
          0,
          str.substring(index).indexOf(_space),
        );
  }
}

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

  static void _log(
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
      _log(
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
      _log(
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
      _log(
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
      _log(
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
      _log(
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
      _log(
        LoggingLevel.fatal,
        value,
        error: error,
        stackTrace: stackTrace,
        time: time,
      );
}
