import '../widgets/log_console.dart';
import 'log_store.dart';
import 'global_config.dart';

/// Helper for logging messages from anywhere in the app.
void addAppLog(String message, {LogLevel level = LogLevel.info}) {
  final console = logConsoleKey.currentState;
  if (console != null) {
    console.addLog(message, level: level);
  } else {
    LogStore.addLog(level, message);
  }
}
