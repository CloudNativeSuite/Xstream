// lib/services/update/update_platform.dart
import 'dart:io';

enum UpdateChannel { stable, latest }

class UpdatePlatform {
  static String getRepoName(UpdateChannel channel) {
    final os = switch (Platform.operatingSystem) {
      'macos'   => 'macos',
      'windows' => 'windows',
      'android' => 'android',
      'linux'   => 'linux',
      _ => throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}'),
    };
    final tier = switch (channel) {
      UpdateChannel.latest => 'latest',
      UpdateChannel.stable => 'stable',
    };
    return 'xstream/$os/$tier';
  }
}
