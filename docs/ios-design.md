# iOS XStream 设计概述

本文档简要说明 XStream 在 iOS 平台的整体实现思路，侧重原生桥接与 NetworkExtension 的配合方案。

## 架构一览

```
┌──────────────────────────────┐
│       iOS App         │
│ ┌──────────────────────────┐ │
│ │ Swift / Flutter 前端界面 │ │
│ └────────────┬─────────────┘ │
│              │               │
│ ┌────────────▼────────────┐  │
│ │ Embedded xray-core lib  │  │ ← Go 编译为静态库 .a
│ └────────────┬────────────┘  │
│              │               │
│    Proxy Controller /       │
│    Tunnel Provider Module   │ ← 调用 NEPacketTunnelProvider 开启 VPN
└──────────────┼──────────────┘
               ▼
      iOS NetworkExtension
```

与 macOS 类似，iOS 版本也在原生层包装 xray-core。但由于系统权限限制，所有文件仅能写入 App 沙箱目录，并通过 `NETunnelProvider` 将系统流量转发到本地监听端口。

## xray-core 集成

1. 在项目根目录运行 `./build_scripts/build_ios_xray.sh` 生成 `libxray.a` 与 `libxray.h`。脚本会在 `build/ios` 目录输出编译结果，并使用 `GOOS=ios GOARCH=arm64` 进行构建。
2. 将生成的静态库放入 Xcode 的 `Frameworks` 目录并链接，随后即可通过 `StartXray`/`StopXray` 在原生层控制代理实例。
3. 编译 [xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks) Rust 项目，产出 `libtun2socks.a` 与 `tun2socks.h`，并加入 PacketTunnel Extension 的链接与头文件搜索路径中。
4. Flutter 端直接使用 Dart FFI 调用上述接口，无需额外 Swift 桥接代码。
5. 若需要调试，可在模拟器上使用 `GOARCH=arm64` 构建并运行。

## 配置能力

- 支持导入 VLESS、Reality 协议节点。
- Flutter 端根据用户输入生成标准 xray JSON 配置，调用 `writeConfigFiles` 写入沙箱目录。
- 配置文件示例位于 `~/Library/Application Support/Xstream/`（模拟器路径）下。

## 限制与差异

- iOS 不支持 `launchctl`，因此服务控制只在应用进程内维持。
- Apple 不允许公开使用 `NSTask`，如需调用需通过私有 API 或 FFI；文档示例采用 FFI 方式。
- 由于沙箱机制，无法使用 `tproxy`，仅支持 VPN 模式代理。

## 参考

- Apple 官方文档：NetworkExtension Programming Guide
- xray-core / sing-box 项目文档
