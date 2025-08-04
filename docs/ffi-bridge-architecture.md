# Flutter + Go FFI 跨平台桥接架构

本篇文档概述 XStream 在 Windows 与 Linux 平台上如何利用 `dart:ffi` 与 Go 进行通信，
从而避免使用 C++ 与平台通道带来的复杂性。macOS 仍沿用原有的 Flutter 插件实现，
其他平台均通过动态库提供统一的接口。

## 层次划分

| 层次     | 技术栈                            | 说明                                     |
|----------|-----------------------------------|------------------------------------------|
| UI 层    | Flutter                           | 页面展示与用户交互                       |
| 绑定层   | dart:ffi                          | 连接 Dart 与 C ABI                       |
| 桥接层   | Go (cgo + `-buildmode=c-shared`)  | 暴露 C 接口，内部使用 Go 实现核心逻辑     |
| 原生层   | Go                                | 处理配置、服务管理与系统调用             |

## 编译产物

- **Windows**：生成 `nativebridge.dll`
- **Linux**：生成 `libnative_bridge.so`

建议在 Linux 环境使用静态链接，Windows 则尽量减少额外的动态依赖。

## 构建示例

```bash
# Linux
GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
  go build -buildmode=c-shared -o libnative_bridge.so ./go/nativebridge.go

# Windows
GOOS=windows GOARCH=amd64 CGO_ENABLED=1 \
  go build -buildmode=c-shared -o nativebridge.dll ./go/nativebridge.go
```

生成的动态库放置在与可执行文件同级的目录下，`NativeBridge` 会在运行时加载并
调用其中导出的函数，若未找到对应文件则自动回退至 `MethodChannel`。

macOS 版本继续通过 Flutter 插件与 Swift 交互，Windows 和 Linux 则使用 `dart:ffi` 调用上文生成的动态库，当库不可用时仍会退回 `MethodChannel` 以保证兼容性。
