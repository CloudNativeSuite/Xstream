import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/help_screen.dart';
import 'screens/about_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'utils/app_theme.dart';
import 'utils/native_bridge.dart';
import 'utils/global_config.dart' show GlobalState, DnsConfig;
import 'utils/app_logger.dart';
import 'services/telemetry/telemetry_service.dart';
import 'services/vpn_config_service.dart';
import 'services/global_proxy_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await TelemetryService.init();
  await DnsConfig.init();
  await GlobalProxyService.init();
  final debug = args.contains('--debug') ||
      Platform.executableArguments.contains('--debug');
  GlobalState.debugMode.value = debug;
  if (debug) {
    debugPrint('🚀 Flutter main() started in debug mode');
  }
  await VpnConfig.load(); // ✅ 启动时加载 assets + 本地配置
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: GlobalState.locale,
      builder: (context, locale, _) {
        return MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          title: 'XStream',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const MainPage(),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ 注册生命周期观察器

    NativeBridge.initializeLogger((log) {
      addAppLog("[macOS] $log");
    });

    GlobalState.connectionMode.addListener(_onConnectionModeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ 注销生命周期观察器
    GlobalState.connectionMode.removeListener(_onConnectionModeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      // ✅ 退出前自动保存配置
      VpnConfig.saveToFile();
    }
  }

  Future<void> _promptUnlockDialog() async {
    String? password = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(context.l10n.get('unlockPrompt')),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(labelText: context.l10n.get('password')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.get('cancel'))),
            TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.l10n.get('confirm'))),
          ],
        );
      },
    );

    if (password != null && password.isNotEmpty) {
      GlobalState.isUnlocked.value = true;
      GlobalState.sudoPassword.value = password;
    }
  }

  void _lock() {
    GlobalState.isUnlocked.value = false;
    GlobalState.sudoPassword.value = '';
  }

  void _openAddConfig() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final current = GlobalState.locale.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<Locale>(
              value: const Locale('zh'),
              groupValue: current,
              title: const Text('中文'),
              onChanged: (loc) {
                if (loc != null) GlobalState.locale.value = loc;
                Navigator.pop(context);
              },
            ),
            RadioListTile<Locale>(
              value: const Locale('en'),
              groupValue: current,
              title: const Text('English'),
              onChanged: (loc) {
                if (loc != null) GlobalState.locale.value = loc;
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showModeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<String>(
          valueListenable: GlobalState.connectionMode,
          builder: (context, mode, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Radio<String>(
                    value: 'VPN',
                    groupValue: mode,
                    onChanged: (v) {
                      if (v != null) GlobalState.connectionMode.value = v;
                      Navigator.pop(context);
                    },
                  ),
                  title: Text(context.l10n.get('vpn')),
                ),
                ListTile(
                  leading: Radio<String>(
                    value: '仅代理',
                    groupValue: mode,
                    onChanged: (v) {
                      if (v != null) GlobalState.connectionMode.value = v;
                      Navigator.pop(context);
                    },
                  ),
                  title: Text(context.l10n.get('proxyOnly')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onConnectionModeChanged() async {
    if (!GlobalState.isUnlocked.value) return;
    final password = GlobalState.sudoPassword.value;
    if (password.isEmpty) return;

    final mode = GlobalState.connectionMode.value;
    addAppLog('切换模式为 $mode');
    String msg;
    if (mode == 'VPN') {
      msg = await Tun2socksService.start(password);
    } else {
      msg = await Tun2socksService.stop(password);
    }
    addAppLog('[tun2socks] $msg');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const SubscriptionScreen(),
      const SettingsScreen(),
      const LogsScreen(),
      const HelpScreen(),
      const AboutScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            tooltip: context.l10n.get('language'),
            icon: const Icon(Icons.language),
            onPressed: _showLanguageSelector,
          ),
          IconButton(
            tooltip: context.l10n.get('addConfig'),
            icon: const Icon(Icons.add),
            onPressed: _openAddConfig,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: GlobalState.isUnlocked,
            builder: (context, unlocked, _) {
              return IconButton(
                icon: Icon(unlocked ? Icons.lock_open : Icons.lock),
                onPressed: unlocked ? _lock : _promptUnlockDialog,
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(icon: const Icon(Icons.home), label: Text(context.l10n.get('home'))),
              NavigationRailDestination(icon: const Icon(Icons.link), label: Text(context.l10n.get('proxy'))),
              NavigationRailDestination(icon: const Icon(Icons.settings), label: Text(context.l10n.get('settings'))),
              NavigationRailDestination(icon: const Icon(Icons.article), label: Text(context.l10n.get('logs'))),
              NavigationRailDestination(icon: const Icon(Icons.help), label: Text(context.l10n.get('help'))),
              NavigationRailDestination(icon: const Icon(Icons.info), label: Text(context.l10n.get('about'))),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: IndexedStack(index: _currentIndex, children: pages)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showModeSelector,
        child: const Icon(Icons.tune),
      ),
    );
  }
}
