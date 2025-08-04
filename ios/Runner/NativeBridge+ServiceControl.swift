import Foundation
import Flutter

extension AppDelegate {
  func handleServiceControl(call: FlutterMethodCall, result: @escaping FlutterResult) {
    logToFlutter("warn", "\(call.method) not supported on iOS")
    switch call.method {
    case "startNodeService", "stopNodeService":
      result("iOS not supported")
    case "checkNodeStatus":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
