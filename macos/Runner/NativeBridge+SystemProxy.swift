import Foundation
import FlutterMacOS

extension AppDelegate {
  func handleSystemProxy(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let enable = args["enable"] as? Bool,
          let password = args["password"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing enable/password", details: nil))
      return
    }

    switch call.method {
    case "setSystemProxy":
      runSetSystemProxy(enable: enable, password: password, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func runSetSystemProxy(enable: Bool, password: String, result: @escaping FlutterResult) {
    let script: String
    if enable {
      script = """
services=$(networksetup -listallnetworkservices | tail +2)
for s in $services; do
  networksetup -setsocksfirewallproxy "$s" 127.0.0.1 1080
  networksetup -setsocksfirewallproxystate "$s" on
done
"""
    } else {
      script = """
services=$(networksetup -listallnetworkservices | tail +2)
for s in $services; do
  networksetup -setsocksfirewallproxystate "$s" off
done
"""
    }
    let escaped = script.replacingOccurrences(of: "\"", with: "\\\"")
    let command = "echo \"\(password)\" | sudo -S bash -c \"\(escaped)\""
    runShellScript(command: command, returnsBool: false, result: result)
  }
}
