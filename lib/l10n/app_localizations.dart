import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'unlockPrompt': 'Enter password to unlock',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'password': 'Password',
      'vpn': 'Tunnel Mode',
      'proxyOnly': 'Proxy Mode',
      'home': 'Home',
      'proxy': 'Proxy',
      'settings': 'Settings',
      'logs': 'Logs',
      'help': 'Help',
      'about': 'About',
      'addConfig': 'Add Config',
      'serviceRunning': '⚠️ Service already running',
      'noNodes': 'No nodes, please add.',
      'generateSave': 'Generate & Save',
      'addNodeConfig': 'Add Node Config',
      'nodeName': 'Node Name (e.g., US-Node)',
      'serverDomain': 'Server Domain',
      'port': 'Port',
      'uuid': 'UUID',
      'openManual': 'Open Manual',
      'logExported': '📤 Logs exported to console',
      'clearLogs': '🧹 Clear logs',
      'exportLogs': '📤 Export logs',
      'settingsCenter': '⚙️ Settings',
      'xrayMgmt': 'Xray Management',
      'initXray': 'Init Xray',
      'updateXray': 'Update Xray Core',
      'configMgmt': 'Config Management',
      'genDefaultNodes': 'Generate Default Nodes',
      'resetAll': 'Reset All Configs',
      'syncConfig': 'Sync Config',
      'deleteConfig': 'Delete Config',
      'saveConfig': 'Save Config',
      'importConfig': 'Import Config',
      'exportConfig': 'Export Config',
      'advancedConfig': 'Advanced',
      'dnsConfig': 'DNS Settings',
      'primaryDns': 'Primary DNS',
      'secondaryDns': 'Secondary DNS',
      'globalProxy': 'Global Proxy',
      'experimentalFeatures': 'Experimental Features',
      'tunnelProxyMode': 'Tunnel Mode',
      'modeSwitch': 'Switch Connection Mode',
      'vpnDesc': 'tunxxx interface',
      'proxyDesc': 'socks5://127.0.0.1:1080  http://127.0.0.1:1081',
      'unlockFirst': 'Please unlock to init',
      'upgradeDaily': 'Upgrade DailyBuild',
      'viewCollected': 'View collected data',
      'checkUpdate': 'Check Update',
      'collectedData': 'Collected Data',
      'close': 'Close',
      'upToDate': 'Already up to date',
      'language': 'Language',
    },
    'zh': {
      'unlockPrompt': '输入密码解锁',
      'cancel': '取消',
      'confirm': '确认',
      'password': '密码',
      'vpn': '隧道模式',
      'proxyOnly': '代理模式',
      'home': '首页',
      'proxy': '代理',
      'settings': '设置',
      'logs': '日志',
      'help': '帮助',
      'about': '关于',
      'addConfig': '添加配置文件',
      'serviceRunning': '⚠️ 服务已在运行',
      'noNodes': '暂无加速节点，请先添加。',
      'generateSave': '生成配置并保存',
      'addNodeConfig': '添加加速节点配置',
      'nodeName': '节点名（如 US-Node）',
      'serverDomain': '服务器域名',
      'port': '端口号',
      'uuid': 'UUID',
      'openManual': '打开使用文档',
      'logExported': '📤 日志已导出至控制台',
      'clearLogs': '🧹 清空日志',
      'exportLogs': '📤 导出日志',
      'settingsCenter': '⚙️ 设置中心',
      'xrayMgmt': 'Xray 管理',
      'initXray': '初始化 Xray',
      'updateXray': '更新 Xray Core',
      'configMgmt': '配置管理',
      'genDefaultNodes': '生成默认节点',
      'resetAll': '重置所有配置',
      'syncConfig': '同步配置',
      'deleteConfig': '删除配置',
      'saveConfig': '保存配置',
      'importConfig': '导入配置',
      'exportConfig': '导出配置',
      'advancedConfig': '高级配置',
      'dnsConfig': 'DNS 配置',
      'primaryDns': '主 DNS',
      'secondaryDns': '备用 DNS',
      'globalProxy': '全局代理',
      'experimentalFeatures': '实验特性',
      'tunnelProxyMode': '隧道模式',
      'modeSwitch': '切换连接模式',
      'vpnDesc': 'tunxxx网卡',
      'proxyDesc': 'socks5://127.0.0.1:1080  http://127.0.0.1:1081',
      'unlockFirst': '请先解锁以执行初始化操作',
      'upgradeDaily': '升级 DailyBuild',
      'viewCollected': '查看收集内容',
      'checkUpdate': '检查更新',
      'collectedData': '收集内容',
      'close': '关闭',
      'upToDate': '已是最新版本',
      'language': '语言',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key] ??
        key;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations)!;
}
