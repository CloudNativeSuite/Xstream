import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../utils/global_config.dart';

class DeviceFingerprint {
  static const length = 32;

  static Future<Uint8List> loadOrCreate() async {
    final path = await GlobalApplicationConfig.getDeviceFingerprintFilePath();
    final file = File(path);
    if (await file.exists()) {
      final data = await file.readAsBytes();
      if (data.length == length) {
        return Uint8List.fromList(data);
      }
    }

    final random = Random.secure();
    final buffer = Uint8List(length);
    for (var i = 0; i < length; i++) {
      buffer[i] = random.nextInt(256);
    }
    await file.create(recursive: true);
    await file.writeAsBytes(buffer, flush: true);
    return buffer;
  }
}
