import 'package:flutter/material.dart';
import '../widgets/log_console.dart';
import '../utils/global_config.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LogConsole(key: logConsoleKey),
    );
  }
}
