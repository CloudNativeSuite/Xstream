import Foundation
import Flutter

extension AppDelegate {
  func writeConfigFiles(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let xrayConfigPath = args["xrayConfigPath"] as? String,
          let xrayConfigContent = args["xrayConfigContent"] as? String,
          let servicePath = args["servicePath"] as? String,
          let serviceContent = args["serviceContent"] as? String,
          let vpnNodesConfigPath = args["vpnNodesConfigPath"] as? String,
          let vpnNodesConfigContent = args["vpnNodesConfigContent"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters", details: nil))
      return
    }

    do {
      try xrayConfigContent.write(toFile: xrayConfigPath, atomically: true, encoding: .utf8)
      try serviceContent.write(toFile: servicePath, atomically: true, encoding: .utf8)
      try vpnNodesConfigContent.write(toFile: vpnNodesConfigPath, atomically: true, encoding: .utf8)
      result("success")
      logToFlutter("info", "Config files written to sandbox")
    } catch {
      result(FlutterError(code: "WRITE_ERROR", message: "Failed to write files", details: error.localizedDescription))
      logToFlutter("error", "Failed to write files: \(error.localizedDescription)")
    }
  }
}
