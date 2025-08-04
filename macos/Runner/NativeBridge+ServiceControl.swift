import Foundation
import FlutterMacOS

extension AppDelegate {
  func handleServiceControl(call: FlutterMethodCall, bundleId: String, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let serviceNameArg = args["serviceName"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing serviceName", details: nil))
      return
    }

    let userName = NSUserName()
    let uid = getuid()
    let servicePath = "/Users/\(userName)/Library/LaunchAgents/\(serviceNameArg)"
    let serviceName = serviceNameArg.replacingOccurrences(of: ".plist", with: "")

    // 检查 macOS 是否为现代版本（>= 10.15）
    let os = ProcessInfo.processInfo.operatingSystemVersion
    let useModernLaunchctl = os.majorVersion >= 11 || (os.majorVersion == 10 && os.minorVersion >= 15)

    switch call.method {
    case "startNodeService":
      let command = useModernLaunchctl
        ? "launchctl bootstrap gui/\(uid) \"\(servicePath)\""
        : "launchctl load \"\(servicePath)\""
      runShellScript(command: command, returnsBool: false, result: result)

    case "stopNodeService":
      let command = useModernLaunchctl
        ? "launchctl bootout gui/\(uid) \"\(servicePath)\""
        : "launchctl unload \"\(servicePath)\""
      runShellScript(command: command, returnsBool: false, result: result)

    case "checkNodeStatus":
      let command = useModernLaunchctl
        ? "launchctl print gui/\(uid)/\(serviceName)"
        : "launchctl list | grep \"\(serviceName)\""
      runShellScript(command: command, returnsBool: true, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func runShellScript(command: String, returnsBool: Bool, result: @escaping FlutterResult) {
    let task = Process()
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
      try task.run()
      task.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""
      let isSuccess = (task.terminationStatus == 0)

      // ✅ 处理 checkNodeStatus
      if returnsBool {
        // 高版本: launchctl print
        if command.contains("launchctl print") {
          let isRunning = output.contains("state = running") || output.contains("PID =")
          result(isRunning)
          return
        }
        // 低版本: launchctl list | grep
        if command.contains("launchctl list") {
          let isListed = isSuccess && !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          result(isListed)
          return
        }
        // 默认 fallback
        result(false)
        return
      }
      // ✅ 非 checkNodeStatus 情况
      if isSuccess {
        result("success")
        let safeCommand = maskSensitive(command)
        self.logToFlutter("info", "命令执行成功: \nCommand: \(safeCommand)\nOutput: \(output)")
      } else {
        if command.contains("bootstrap") && output.contains("Service is already loaded") {
          result("服务已在运行")
          let safeCommand = maskSensitive(command)
          self.logToFlutter("warn", "服务已在运行（重复启动）: \(safeCommand)")
        } else {
          result(FlutterError(code: "EXEC_FAILED", message: "Command failed", details: output))
          let safeCommand = maskSensitive(command)
          self.logToFlutter("error", "命令执行失败: \nCommand: \(safeCommand)\nOutput: \(output)")
        }
      }
    } catch {
      result(FlutterError(code: "EXEC_ERROR", message: "Process failed to run", details: error.localizedDescription))
      self.logToFlutter("error", "Process failed to run: \(error.localizedDescription)")
    }
  }

  private func maskSensitive(_ command: String) -> String {
    let pattern = #"echo\s+\"([^\"]+)\"\s*\|\s*sudo\s+-S"#
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
      let range = NSRange(command.startIndex..., in: command)
      return regex.stringByReplacingMatches(in: command, options: [], range: range, withTemplate: "echo \"****\" | sudo -S")
    }
    return command
  }
}
