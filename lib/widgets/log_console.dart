import 'package:flutter/material.dart';
import '../utils/log_store.dart';
import '../l10n/app_localizations.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  LogEntry(this.level, this.message) : timestamp = DateTime.now();

  String get formatted =>
      "[${_levelString(level)}] ${timestamp.toIso8601String()}: $message";

  static String _levelString(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return "INFO";
      case LogLevel.warning:
        return "WARN";
      case LogLevel.error:
        return "ERROR";
    }
  }
}

class LogConsole extends StatefulWidget {
  const LogConsole({super.key});

  @override
  LogConsoleState createState() => LogConsoleState();
}

class LogConsoleState extends State<LogConsole> {
  final List<LogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _logs.addAll(LogStore.getAll());
  }

  void addLog(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(level, message);
    setState(() {
      _logs.add(entry);
    });
    LogStore.add(entry); // ⬅️ 同步写入共享全局日志
  }

  void clearLogs() {
    setState(() {
      _logs.clear();
    });
    LogStore.clear(); // ⬅️ 清空全局日志
  }

  void exportLogs() {
    final logText = _logs.map((e) => e.formatted).join('\n');
    debugPrint(logText);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.get('logExported'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: clearLogs,
              child: Text(context.l10n.get('clearLogs')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: exportLogs,
              child: Text(context.l10n.get('exportLogs')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black87,
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Text(
                  log.formatted,
                  style: TextStyle(
                    color: _getColor(log.level),
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Color _getColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.white;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.redAccent;
    }
  }
}
