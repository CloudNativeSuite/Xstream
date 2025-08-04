import 'package:shared_preferences/shared_preferences.dart';

import '../utils/global_config.dart' show GlobalState;

class GlobalProxyService {
  static const _prefsKey = 'globalProxyEnabled';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKey) ?? false;
    GlobalState.globalProxy.value = enabled;
    GlobalState.globalProxy.addListener(() {
      prefs.setBool(_prefsKey, GlobalState.globalProxy.value);
    });
  }
}
