import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../widgets/log_console.dart';

const String kArtifactHost = 'artifact.svc.plus';
const String kUpdateBaseUrl = 'https://$kArtifactHost/';

// LogConsole Global Key
final GlobalKey<LogConsoleState> logConsoleKey = GlobalKey<LogConsoleState>();

/// 当前构建版本号，可在应用各处引用
final String buildVersion = (() {
  const branch = String.fromEnvironment('BRANCH_NAME', defaultValue: '');
  const buildId = String.fromEnvironment('BUILD_ID', defaultValue: 'local');
  const buildDate = String.fromEnvironment('BUILD_DATE', defaultValue: 'unknown');

  if (branch.startsWith('release/')) {
    final version = branch.replaceFirst('release/', '');
    return 'v$version-$buildDate-$buildId';
  }
  if (branch == 'main') {
    return 'latest-$buildDate-$buildId';
  }
  return 'dev-$buildDate-$buildId';
})();

/// 基础系统信息，用于匿名统计等场景
Map<String, String> collectSystemInfo() => {
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
    };

/// 全局应用状态管理（使用 ValueNotifier 实现响应式绑定）
class GlobalState {
  /// 解锁状态（true 表示已解锁）
  static final ValueNotifier<bool> isUnlocked = ValueNotifier<bool>(false);

  /// 当前解锁使用的 sudo 密码（可供原生调用或配置操作使用）
  static final ValueNotifier<String> sudoPassword = ValueNotifier<String>('');

  /// 升级渠道：true 表示检查 DailyBuild，false 只检查 release
  static final ValueNotifier<bool> useDailyBuild = ValueNotifier<bool>(false);

  /// 调试模式开关，由 `--debug` 参数控制
  static final ValueNotifier<bool> debugMode = ValueNotifier<bool>(false);

  /// 遥测开关：true 表示发送匿名统计信息
  static final ValueNotifier<bool> telemetryEnabled = ValueNotifier<bool>(false);

  /// Xray Core 下载状态
  static final ValueNotifier<bool> xrayUpdating = ValueNotifier<bool>(false);
}

/// 用于获取应用相关的配置信息
class GlobalApplicationConfig {
  /// Windows 平台默认安装目录
  static String get windowsBasePath {
    final base = Platform.environment['ProgramFiles'] ?? 'C:\\Program Files';
    return '$base\\Xstream';
  }

  /// Xray 可执行文件路径
  static String get xrayExePath {
    switch (Platform.operatingSystem) {
      case 'windows':
        return '$windowsBasePath\\xray.exe';
      case 'linux':
        final home = Platform.environment['HOME'] ?? '~';
        return '$home/.local/bin/xray';
      default:
        return '/usr/local/bin/xray';
    }
  }
  /// 从配置文件或默认值中获取 PRODUCT_BUNDLE_IDENTIFIER
  static Future<String> getBundleId() async {
    if (Platform.isMacOS) {
      try {
        // 读取 macOS 配置文件，获取 PRODUCT_BUNDLE_IDENTIFIER
        final config = await rootBundle.loadString('macos/Runner/Configs/AppInfo.xcconfig');
        final line = config
            .split('\n')
            .firstWhere((l) => l.startsWith('PRODUCT_BUNDLE_IDENTIFIER='));
        return line.split('=').last.trim();
      } catch (_) {
        // macOS 下若读取失败返回默认值
        return 'com.xstream';
      }
    }

    // 其他平台直接返回默认值
    return 'com.xstream';
  }

  /// 返回各平台下存放 Xray 配置文件的目录，末尾已包含分隔符
  static String get xrayConfigPath {
    switch (Platform.operatingSystem) {
      case 'macos':
        return '/opt/homebrew/etc/';
      case 'windows':
        final base = Platform.environment['ProgramFiles'] ?? 'C:\\Program Files';
        return '$base\\Xstream\\';
      case 'linux':
        return '/opt/etc/';
      default:
        return '';
    }
  }

  /// 根据平台返回本地配置文件路径
  static Future<String> getLocalConfigPath() async {
    switch (Platform.operatingSystem) {
      case 'macos':
        final bundleId = await getBundleId();
        final baseDir = await getApplicationSupportDirectory();
        final xstreamDir = Directory('${baseDir.path}/$bundleId');
        await xstreamDir.create(recursive: true);
        return '${xstreamDir.path}/vpn_nodes.json';

      case 'windows':
        final base = Platform.environment['ProgramFiles'] ??
            (await getApplicationSupportDirectory()).path;
        final xstreamDir = Directory('$base\\Xstream');
        await xstreamDir.create(recursive: true);
        return '${xstreamDir.path}\\vpn_nodes.json';

      case 'linux':
        final home = Platform.environment['HOME'] ??
            (await getApplicationSupportDirectory()).path;
        final xstreamDir = Directory('$home/.config/xstream');
        await xstreamDir.create(recursive: true);
        return '${xstreamDir.path}/vpn_nodes.json';

      default:
        final baseDir = await getApplicationSupportDirectory();
        final xstreamDir = Directory('${baseDir.path}/xstream');
        await xstreamDir.create(recursive: true);
        return '${xstreamDir.path}/vpn_nodes.json';
    }
  }

  /// 根据 region 生成各平台的启动控制文件或任务名称
  static Future<String> serviceNameForRegion(String region) async {
    final code = region.toLowerCase();
    switch (Platform.operatingSystem) {
      case 'macos':
        final bundleId = await getBundleId();
        return '$bundleId.xray-node-$code.plist';
      case 'linux':
        return 'xray-node-$code.service';
      case 'windows':
        return 'ray-node-$code.schtasks';
      default:
        return 'xray-node-$code';
    }
  }

  /// 根据平台和服务名称返回服务配置文件路径
  static String servicePath(String serviceName) {
    switch (Platform.operatingSystem) {
      case 'macos':
        final home = Platform.environment['HOME'] ?? '/Users/unknown';
        return '$home/Library/LaunchAgents/$serviceName';
      case 'linux':
        return '/etc/systemd/system/$serviceName';
      case 'windows':
        final base = Platform.environment['ProgramFiles'] ?? 'C:\\Program Files';
        return '$base\\Xstream\\$serviceName';
      default:
        return serviceName;
    }
  }
}
