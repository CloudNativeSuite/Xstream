import 'dart:io';

import '../../services/vpn_config_service.dart';
import '../../utils/global_config.dart';

class XrayConfigWriter {
  static const _configFileName = 'desktop_sync.json';
  static const _defaultNodeName = 'Desktop Sync';
  static const _defaultServiceName = 'xstream.desktop.sync';
  static const _defaultCountryCode = 'CN';

  static Future<String> writeConfig(String json) async {
    final path =
        await GlobalApplicationConfig.getXrayConfigFilePath(_configFileName);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(json);
    return path;
  }

  static Future<void> registerNode(String configPath) async {
    final existing = VpnConfig.getNodeByName(_defaultNodeName);
    final node = VpnNode(
      name: _defaultNodeName,
      countryCode: existing?.countryCode ?? _defaultCountryCode,
      configPath: configPath,
      serviceName: existing?.serviceName ?? _defaultServiceName,
      enabled: existing?.enabled ?? true,
    );
    if (existing == null) {
      VpnConfig.addNode(node);
    } else {
      VpnConfig.updateNode(node);
    }
    await VpnConfig.saveToFile();
  }
}
