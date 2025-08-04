import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/global_config.dart'
    show GlobalState, buildVersion, DnsConfig;
import '../../utils/native_bridge.dart';
import '../l10n/app_localizations.dart';
import '../../services/vpn_config_service.dart';
import '../../services/update/update_checker.dart';
import '../../services/update/update_platform.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../utils/app_logger.dart';
import '../widgets/log_console.dart' show LogLevel;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Timer? _xrayMonitorTimer;

  static const TextStyle _menuTextStyle = TextStyle(fontSize: 14);
  static final ButtonStyle _menuButtonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(36),
    textStyle: _menuTextStyle,
  );

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    ButtonStyle? style,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: style ?? _menuButtonStyle,
        icon: Icon(icon),
        label: Text(label, style: _menuTextStyle),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  String _currentVersion() {
    final match = RegExp(r'v(\d+\.\d+\.\d+)').firstMatch(buildVersion);
    return match?.group(1) ?? '0.0.0';
  }

  void _onGenerateDefaultNodes() async {
    final isUnlocked = GlobalState.isUnlocked.value;
    final password = GlobalState.sudoPassword.value;

    if (!isUnlocked) {
      addAppLog('请先解锁以执行生成操作', level: LogLevel.warning);
      return;
    }

    addAppLog('开始生成默认节点...');
    await VpnConfig.generateDefaultNodes(
      password: password,
      setMessage: (msg) => addAppLog(msg),
      logMessage: (msg) => addAppLog(msg),
    );

    // 初始化并重启 tun2socks 服务
    await Tun2socksService.initScripts(password);
    await Tun2socksService.stop(password);
    await Tun2socksService.start(password);
  }

  void _onInitXray() async {
    final isUnlocked = GlobalState.isUnlocked.value;

    if (!isUnlocked) {
      addAppLog('请先解锁以初始化 Xray', level: LogLevel.warning);
      return;
    }

    addAppLog('开始初始化 Xray...');
    try {
      final output = await NativeBridge.initXray();
      addAppLog(output);
    } catch (e) {
      addAppLog('[错误] $e', level: LogLevel.error);
    }
  }

  void _onUpdateXray() async {
    final isUnlocked = GlobalState.isUnlocked.value;

    if (!isUnlocked) {
      addAppLog('请先解锁以更新 Xray', level: LogLevel.warning);
      return;
    }

    addAppLog('开始更新 Xray Core...');
    try {
      final output = await NativeBridge.updateXrayCore();
      addAppLog(output);
      if (output.startsWith('info:')) {
        GlobalState.xrayUpdating.value = true;
        _startMonitorXrayProgress();
      }
    } catch (e) {
      addAppLog('[错误] $e', level: LogLevel.error);
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
      addAppLog('请先解锁以执行重置操作', level: LogLevel.warning);
      return;
    }

    addAppLog('开始重置配置与文件...');
    try {
      final result = await NativeBridge.resetXrayAndConfig(password);
      addAppLog(result);
    } catch (e) {
      addAppLog('[错误] 重置失败: $e', level: LogLevel.error);
    }
  }

  void _onToggleGlobalProxy(bool enabled) async {
    final isUnlocked = GlobalState.isUnlocked.value;
    final password = GlobalState.sudoPassword.value;
    if (!isUnlocked) {
      addAppLog('请先解锁以切换全局代理', level: LogLevel.warning);
      return;
    }
    setState(() => GlobalState.globalProxy.value = enabled);
    final msg = await NativeBridge.setSystemProxy(enabled, password);
    addAppLog('全局代理: ${enabled ? "开启" : "关闭"}');
    addAppLog('[system proxy] $msg');
  }

  void _onCheckUpdate() {
    addAppLog('开始检查更新...');
    UpdateChecker.manualCheck(
      context,
      currentVersion: _currentVersion(),
      channel: GlobalState.useDailyBuild.value
          ? UpdateChannel.latest
          : UpdateChannel.stable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.get('settingsCenter'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: GlobalState.isUnlocked,
              builder: (context, isUnlocked, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(context.l10n.get('xrayMgmt'), [
                      _buildButton(
                        icon: Icons.build,
                        label: context.l10n.get('initXray'),
                        onPressed: isUnlocked ? _onInitXray : null,
                      ),
                      _buildButton(
                        icon: Icons.update,
                        label: context.l10n.get('updateXray'),
                        onPressed: isUnlocked ? _onUpdateXray : null,
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
                    ]),
                    _buildSection(context.l10n.get('configMgmt'), [
                      _buildButton(
                        icon: Icons.settings,
                        label: context.l10n.get('genDefaultNodes'),
                        onPressed: isUnlocked ? _onGenerateDefaultNodes : null,
                      ),
                      _buildButton(
                        icon: Icons.security,
                        label: context.l10n.get('permissionGuide'),
                        onPressed: _showPermissionGuide,
                      ),
                      _buildButton(
                        icon: Icons.restore,
                        label: context.l10n.get('resetAll'),
                        style: _menuButtonStyle.copyWith(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.red[400]),
                        ),
                        onPressed: isUnlocked ? _onResetAll : null,
                      ),
                    ]),
                    _buildSection(context.l10n.get('advancedConfig'), [
                      _buildButton(
                        icon: Icons.dns,
                        label: context.l10n.get('dnsConfig'),
                        onPressed: _showDnsDialog,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: SwitchListTile(
                          value: GlobalState.globalProxy.value,
                          onChanged: _onToggleGlobalProxy,
                          title: Text(
                            context.l10n.get('globalProxy'),
                            style: _menuTextStyle,
                          ),
                        ),
                      ),
                    ]),
                    _buildSection(context.l10n.get('experimentalFeatures'), [
                      SizedBox(
                        width: double.infinity,
                        child: SwitchListTile(
                          secondary: const Icon(Icons.science),
                          title: Text(context.l10n.get('tunnelProxyMode'),
                              style: _menuTextStyle),
                          value: GlobalState.tunnelProxyEnabled.value,
                          onChanged: (v) {
                            setState(() =>
                                GlobalState.tunnelProxyEnabled.value = v);
                          },
                        ),
                      ),
                    ]),
                    if (!isUnlocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          context.l10n.get('unlockFirst'),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 32),
            SwitchListTile(
              secondary: const Icon(Icons.bolt),
              title:
                  Text(context.l10n.get('upgradeDaily'), style: _menuTextStyle),
              value: GlobalState.useDailyBuild.value,
              onChanged: (v) {
                setState(() => GlobalState.useDailyBuild.value = v);
                addAppLog('升级 DailyBuild: ${v ? "开启" : "关闭"}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.stacked_line_chart),
              title: Text(context.l10n.get('viewCollected'),
                  style: _menuTextStyle),
              trailing: Switch(
                value: GlobalState.telemetryEnabled.value,
                onChanged: (v) {
                  setState(() => GlobalState.telemetryEnabled.value = v);
                  addAppLog('Telemetry: ${v ? "开启" : "关闭"}');
                },
              ),
              onTap: _showTelemetryData,
            ),
            ListTile(
              leading: const Icon(Icons.system_update),
              title:
                  Text(context.l10n.get('checkUpdate'), style: _menuTextStyle),
              onTap: _onCheckUpdate,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _xrayMonitorTimer?.cancel();
    super.dispose();
  }

  void _showDnsDialog() {
    final dns1Controller = TextEditingController(text: DnsConfig.dns1.value);
    final dns2Controller = TextEditingController(text: DnsConfig.dns2.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.get('dnsConfig')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dns1Controller,
              decoration:
                  InputDecoration(labelText: context.l10n.get('primaryDns')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dns2Controller,
              decoration:
                  InputDecoration(labelText: context.l10n.get('secondaryDns')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.get('cancel')),
          ),
          TextButton(
            onPressed: () {
              DnsConfig.dns1.value = dns1Controller.text.trim();
              DnsConfig.dns2.value = dns2Controller.text.trim();
              Navigator.pop(context);
            },
            child: Text(context.l10n.get('confirm')),
          ),
        ],
      ),
    );
  }

  void _showTelemetryData() {
    final data = TelemetryService.collectData(appVersion: buildVersion);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.get('collectedData')),
        content: SingleChildScrollView(
          child: SelectableText(json),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.get('close')),
          ),
        ],
      ),
    );
  }

  void _showPermissionGuide() {
    if (GlobalState.permissionGuideDone.value) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.get('permissionGuide')),
          content: Text(context.l10n.get('permissionFinished')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.get('close')),
            ),
          ],
        ),
      );
      return;
    }

    const text = '''1. 允许 /opt/homebrew/、/Library/LaunchDaemons/、~/Library/Application Support/ 目录读写
2. 允许启动和停止 plist 服务
3. 允许修改系统代理与 DNS 设置''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.get('permissionGuide')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.get('permissionGuideIntro')),
              const SizedBox(height: 8),
              const SelectableText(text),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _openSecurityPage,
                child: Text(context.l10n.get('openPrivacy')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              GlobalState.permissionGuideDone.value = true;
              Navigator.pop(context);
            },
            child: Text(context.l10n.get('confirm')),
          ),
        ],
      ),
    );
  }

  void _openSecurityPage() {
    if (Platform.isMacOS) {
      Process.run('open',
          ['x-apple.systempreferences:com.apple.preference.security']);
    } else if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', 'ms-settings:privacy']);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', ['settings://privacy']);
    }
  }
}
