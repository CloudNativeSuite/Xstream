import Foundation
import FlutterMacOS

fileprivate let startTun2socksScript = """
#!/bin/bash

set -e

TUN_DEV=\"utun123\"
TUN_IP=\"198.18.0.1\"
ROUTES=(\"0.0.0.0/1\" \"128.0.0.0/1\")
EXCLUDE=(\"10.0.0.0/8\" \"172.16.0.0/12\" \"192.168.0.0/16\")

GW_IF=$(route get 8.8.8.8 | awk '/interface: /{print $2}')

sudo nohup /opt/homebrew/bin/tun2socks \
  -device \"$TUN_DEV\" \
  -proxy socks5://127.0.0.1:1080 \
  -interface \"$GW_IF\" \
  > /tmp/log 2>&1 &

sleep 1

sudo ifconfig \"$TUN_DEV\" inet \"$TUN_IP\" \"$TUN_IP\" netmask 255.255.255.0 up

for net in \"${ROUTES[@]}\"; do
  sudo route -n add -net \"$net\" -interface \"$TUN_DEV\"
done

for net in \"${EXCLUDE[@]}\"; do
  sudo route -n delete -net \"$net\" 2>/dev/null || true
done

echo \"✅ tun2socks 启动完成，流量已劫持到 $TUN_DEV\"
"""

fileprivate let stopTun2socksScript = """
#!/bin/bash
TUN_DEV=\"utun123\"

echo \"[*] Stopping tun2socks...\"

# 1. 清除路由
for net in 0.0.0.0/1 128.0.0.0/1 198.18.0.0/15; do
  sudo route -n delete -net \"$net\" 2>/dev/null || true
done

# 2. 停止 tun2socks 进程
sudo pkill -f \"tun2socks.*$TUN_DEV\" || true

# 3. 删除 TUN 接口（macOS 自动清理 utunX，但最好加这一句）
sudo ifconfig \"$TUN_DEV\" down 2>/dev/null || true

echo \"[*] tun2socks stopped and routes cleared.\"
"""


extension AppDelegate {
  func handleTun2socks(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let password = args["password"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing password", details: nil))
      return
    }

    switch call.method {
    case "startTun2socks":
      runStartTun2socks(password: password, result: result)
    case "stopTun2socks":
      runStopTun2socks(password: password, result: result)
    case "installTun2socksScripts":
      runInstallTun2socksScripts(password: password, result: result)
    case "installTun2socksPlist":
      if let content = args["content"] as? String {
        runInstallTun2socksPlist(content: content, password: password, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing content", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func runStartTun2socks(password: String, result: @escaping FlutterResult) {
    let plist = "/Library/LaunchDaemons/com.xstream.tun2socks.plist"
    let shell = "echo \"\(password)\" | sudo -S launchctl load -w \"\(plist)\""

    runShellScript(command: shell, returnsBool: false, result: result)
  }

  private func runStopTun2socks(password: String, result: @escaping FlutterResult) {
    let script = "/opt/homebrew/bin/stop_tun2socks.sh"
    let shell = "echo \"\(password)\" | sudo -S bash \"\(script)\""

    runShellScript(command: shell, returnsBool: false, result: result)
  }

  private func runInstallTun2socksScripts(password: String, result: @escaping FlutterResult) {
    let startData = startTun2socksScript.data(using: String.Encoding.utf8)!.base64EncodedString()
    let stopData = stopTun2socksScript.data(using: String.Encoding.utf8)!.base64EncodedString()

    let shell = """
echo \"\(password)\" | sudo -S bash -c 'install_dir=/opt/homebrew/bin
mkdir -p "$install_dir"
echo \"\(startData)\" | base64 -D > "$install_dir/start_tun2socks.sh"
echo \"\(stopData)\" | base64 -D > "$install_dir/stop_tun2socks.sh"
chmod +x "$install_dir/start_tun2socks.sh" "$install_dir/stop_tun2socks.sh"'
"""

    runShellScript(command: shell, returnsBool: false, result: result)
  }

  private func runInstallTun2socksPlist(content: String, password: String, result: @escaping FlutterResult) {
    let data = content.data(using: String.Encoding.utf8)!.base64EncodedString()
    let plist = "/Library/LaunchDaemons/com.xstream.tun2socks.plist"
    let shell = """
echo \"\(password)\" | sudo -S bash -c 'echo \"\(data)\" | base64 -D > \"\(plist)\" && chown root:wheel \"\(plist)\" && chmod 644 \"\(plist)\"'
"""

    runShellScript(command: shell, returnsBool: false, result: result)
  }
}
