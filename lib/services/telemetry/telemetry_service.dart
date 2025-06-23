import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/global_config.dart'
    show GlobalState, collectSystemInfo;

class TelemetryService {
  static const _prefsKey = 'telemetryEnabled';
  static final DateTime _startTime = DateTime.now();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKey) ?? false;
    GlobalState.telemetryEnabled.value = enabled;
    GlobalState.telemetryEnabled.addListener(() {
      prefs.setBool(_prefsKey, GlobalState.telemetryEnabled.value);
    });
  }

  static Map<String, dynamic> collectData({required String appVersion}) {
    final system = collectSystemInfo();
    return {
      'appVersion': appVersion,
      ...system,
      'uptime': DateTime.now().difference(_startTime).inSeconds,
    };
  }
}
