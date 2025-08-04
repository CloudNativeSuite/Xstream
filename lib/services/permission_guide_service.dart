import 'package:shared_preferences/shared_preferences.dart';

import '../utils/global_config.dart' show GlobalState;

class PermissionGuideService {
  static const _prefsKey = 'permissionGuideDone';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_prefsKey) ?? false;
    GlobalState.permissionGuideDone.value = done;
    GlobalState.permissionGuideDone.addListener(() {
      prefs.setBool(_prefsKey, GlobalState.permissionGuideDone.value);
    });
  }
}
