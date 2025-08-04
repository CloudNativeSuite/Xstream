import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/global_config.dart' show GlobalState;

class ExperimentalFeatures {
  static const _tunnelProxyKey = 'tunnelProxyEnabled';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    GlobalState.tunnelProxyEnabled.value =
        prefs.getBool(_tunnelProxyKey) ?? false;
    GlobalState.tunnelProxyEnabled.addListener(() {
      prefs.setBool(_tunnelProxyKey, GlobalState.tunnelProxyEnabled.value);
    });
  }
}
