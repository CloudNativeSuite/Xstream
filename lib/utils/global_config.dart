import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../widgets/log_console.dart';

const String kUpdateBaseUrl = 'https://artifact.onwalk.net/';

// LogConsole Global Key
final GlobalKey<LogConsoleState> logConsoleKey = GlobalKey<LogConsoleState>();

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
}

/// 用于获取应用相关的配置信息
class GlobalApplicationConfig {
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
        final base = Platform.environment['ProgramData'] ??
            (await getApplicationSupportDirectory()).path;
        final xstreamDir = Directory('$base\\xstream');
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
}
