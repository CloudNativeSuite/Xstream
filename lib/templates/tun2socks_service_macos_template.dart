// lib/templates/tun2socks_service_macos_template.dart

const String defaultTun2socksPlistTemplate = r'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.xstream.tun2socks</string>
  <key>ProgramArguments</key>
  <array>
    <string><SCRIPT_DIR>/start_tun2socks.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
''';

String renderTun2socksPlist({required String scriptDir}) {
  return defaultTun2socksPlistTemplate.replaceAll('<SCRIPT_DIR>', scriptDir);
}

