import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utils/global_config.dart' show GlobalState, buildVersion, logConsoleKey;
import '../../utils/native_bridge.dart';
import '../../services/vpn_config_service.dart';
import '../../services/update/update_checker.dart';
import '../../services/update/update_platform.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../widgets/log_console.dart';
import 'help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedTab = 'log';
  Timer? _xrayMonitorTimer;

  static const TextStyle _menuTextStyle = TextStyle(fontSize: 14);
  static final ButtonStyle _menuButtonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(36),
    textStyle: _menuTextStyle,
  );

  String _currentVersion() {
    final match = RegExp(r'v(\d+\.\d+\.\d+)').firstMatch(buildVersion);
    return match?.group(1) ?? '0.0.0';
  }

  void _onGenerateDefaultNodes() async {
    final isUnlocked = GlobalState.isUnlocked.value;
    final password = GlobalState.sudoPassword.value;

    if (!isUnlocked) {
      logConsoleKey.currentState?.addLog('请先解锁以执行生成操作', level: LogLevel.warning);
      return;
    }

    logConsoleKey.currentState?.addLog('开始生成默认节点...');
    await VpnConfig.generateDefaultNodes(
      password: password,
      setMessage: (msg) => logConsoleKey.currentState?.addLog(msg),
      logMessage: (msg) => logConsoleKey.currentState?.addLog(msg),
    );
  }

  void _onInitXray() async {
    final isUnlocked = GlobalState.isUnlocked.value;

    if (!isUnlocked) {
      logConsoleKey.currentState?.addLog('请先解锁以初始化 Xray', level: LogLevel.warning);
      return;
    }

    logConsoleKey.currentState?.addLog('开始初始化 Xray...');
    try {
      final output = await NativeBridge.initXray();
      logConsoleKey.currentState?.addLog(output);
    } catch (e) {
      logConsoleKey.currentState?.addLog('[错误] $e', level: LogLevel.error);
    }
  }

  void _onUpdateXray() async {
    final isUnlocked = GlobalState.isUnlocked.value;

    if (!isUnlocked) {
      logConsoleKey.currentState?.addLog('请先解锁以更新 Xray', level: LogLevel.warning);
      return;
    }

    logConsoleKey.currentState?.addLog('开始更新 Xray Core...');
    try {
      final output = await NativeBridge.updateXrayCore();
      logConsoleKey.currentState?.addLog(output);
      if (output.startsWith('info:')) {
        GlobalState.xrayUpdating.value = true;
        _startMonitorXrayProgress();
      }
    } catch (e) {
      logConsoleKey.currentState?.addLog('[错误] $e', level: LogLevel.error);
    }
  }

  void _startMonitorXrayProgress() {
    _xrayMonitorTimer?.cancel();
    _xrayMonitorTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final running = await NativeBridge.isXrayDownloading();
      GlobalState.xrayUpdating.value = running;
      if (!running) {
        _xrayMonitorTimer?.cancel();
      }
    });
  }

  void _onResetAll() async {
    final isUnlocked = GlobalState.isUnlocked.value;
    final password = GlobalState.sudoPassword.value;

    if (!isUnlocked) {
      logConsoleKey.currentState?.addLog('请先解锁以执行重置操作', level: LogLevel.warning);
      return;
    }

    logConsoleKey.currentState?.addLog('开始重置配置与文件...');
    try {
      final result = await NativeBridge.resetXrayAndConfig(password);
      logConsoleKey.currentState?.addLog(result);
    } catch (e) {
      logConsoleKey.currentState?.addLog('[错误] 重置失败: $e', level: LogLevel.error);
    }
  }

  void _onCheckUpdate() {
    logConsoleKey.currentState?.addLog('开始检查更新...');
    UpdateChecker.manualCheck(
      context,
      currentVersion: _currentVersion(),
      channel: GlobalState.useDailyBuild.value ? UpdateChannel.latest : UpdateChannel.stable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左侧菜单栏
        Container(
          width: 220,
          color: Colors.grey[100],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '⚙️ 设置中心',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: GlobalState.isUnlocked,
                  builder: (context, isUnlocked, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: _menuButtonStyle,
                            icon: const Icon(Icons.build),
                            label: const Text('初始化 Xray', style: _menuTextStyle),
                            onPressed: isUnlocked ? _onInitXray : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: _menuButtonStyle,
                            icon: const Icon(Icons.update),
                            label: const Text('更新 Xray Core', style: _menuTextStyle),
                            onPressed: isUnlocked ? _onUpdateXray : null,
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: GlobalState.xrayUpdating,
                          builder: (context, downloading, _) {
                            return downloading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: LinearProgressIndicator(),
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: _menuButtonStyle,
                            icon: const Icon(Icons.settings),
                            label: const Text('生成默认节点', style: _menuTextStyle),
                            onPressed: isUnlocked ? _onGenerateDefaultNodes : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: _menuButtonStyle.copyWith(
                              backgroundColor: WidgetStateProperty.all(Colors.red[400]),
                            ),
                            icon: const Icon(Icons.restore),
                            label: const Text('重置所有配置', style: _menuTextStyle),
                            onPressed: isUnlocked ? _onResetAll : null,
                          ),
                        ),
                        if (!isUnlocked)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              '请先解锁以执行初始化操作',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.article),
                title: const Text('📜 查看日志', style: _menuTextStyle),
                selected: _selectedTab == 'log',
                onTap: () {
                  setState(() {
                    _selectedTab = 'log';
                  });
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bolt),
                title: const Text('升级 DailyBuild', style: _menuTextStyle),
                value: GlobalState.useDailyBuild.value,
                onChanged: (v) => setState(() => GlobalState.useDailyBuild.value = v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.stacked_line_chart),
                title: const Text('匿名统计', style: _menuTextStyle),
                subtitle: const Text('收集系统版本、运行时间等，可在此关闭'),
                value: GlobalState.telemetryEnabled.value,
                onChanged: (v) {
                  setState(() => GlobalState.telemetryEnabled.value = v);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('查看收集内容', style: _menuTextStyle),
                onTap: _showTelemetryData,
              ),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('检查更新', style: _menuTextStyle),
                onTap: _onCheckUpdate,
              ),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('帮助', style: _menuTextStyle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('关于', style: _menuTextStyle),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'XStream',
                    applicationVersion: buildVersion,
                    applicationLegalese: '''
© 2025 svc.plus

XStream is licensed under the GNU General Public License v3.0.

This application includes components from:
• Xray-core v25.8.3 – https://github.com/XTLS/Xray-core
  Licensed under the Mozilla Public License 2.0
''',
                  );
                },
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _selectedTab == 'log'
                ? LogConsole(key: logConsoleKey)
                : const Center(child: Text('请选择左侧菜单')),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _xrayMonitorTimer?.cancel();
    super.dispose();
  }

  void _showTelemetryData() {
    final data = TelemetryService.collectData(appVersion: buildVersion);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('收集内容'),
        content: SingleChildScrollView(
          child: SelectableText(json),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
