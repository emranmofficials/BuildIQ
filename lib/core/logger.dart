import 'package:flutter/foundation.dart';

class LogEntry {
  final DateTime time;
  final String level;
  final String message;
  final Object? error;

  const LogEntry(this.time, this.level, this.message, this.error);

  @override
  String toString() =>
      '${time.toIso8601String()} [$level] $message${error == null ? '' : ' :: $error'}';
}

/// In-session structured log. Kept in memory so nothing is written without
/// the user's knowledge; critical errors also go to Flutter's error stream.
class AppLogger {
  static final List<LogEntry> entries = <LogEntry>[];

  static void info(String message) => _add('INFO', message);
  static void warn(String message) => _add('WARN', message);
  static void error(String message, [Object? error]) {
    _add('ERROR', message, error);
    debugPrint('$message: $error');
  }

  static void _add(String level, String message, [Object? error]) {
    entries.add(LogEntry(DateTime.now(), level, message, error));
    if (entries.length > 500) entries.removeAt(0);
  }
}
