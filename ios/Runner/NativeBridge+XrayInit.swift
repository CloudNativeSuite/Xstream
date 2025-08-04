import Foundation
import Flutter

extension AppDelegate {
  func handlePerformAction(call: FlutterMethodCall, bundleId: String, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let action = args["action"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing action", details: nil))
      return
    }
    logToFlutter("warn", "\(action) not supported on iOS")
    switch action {
    case "isXrayDownloading":
      result("0")
    case "initXray", "updateXrayCore", "resetXrayAndConfig":
      result("iOS not supported")
    default:
      result(FlutterError(code: "UNKNOWN_ACTION", message: "Unsupported action", details: action))
    }
  }
}
