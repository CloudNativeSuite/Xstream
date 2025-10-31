# XStream Repository Guidelines

本文件为整个仓库的协作说明，适用于 `Xstream/` 下的所有文件与子目录。请在修改代码或文档前阅读并遵循以下约定。

---

## 1. 项目概览
- **前端/客户端：** Flutter 应用位于 `lib/`，通过多屏幕（`screens/`）、服务层（`services/`）、工具库（`utils/`）以及组件库（`widgets/`）组织代码。
- **原生桥接：** `lib/utils/native_bridge.dart` 与 `lib/bindings/` 负责动态库调用，`go_core/` 提供 Go 编写的跨平台桥接逻辑，通过 FFI 暴露到 Flutter。
- **模板与配置：** `lib/templates/` 保存生成 Xray/tun2socks 配置的文本模板；`assets/` 存放静态资源与默认配置；`docs/` 内含平台构建与使用文档。
- **构建脚本：** `Makefile` 和 `build_scripts/` 提供多平台打包流程，需根据目标平台执行不同命令。

---

## 2. 目录速览
- `lib/main.dart`：应用入口与导航容器。
- `lib/utils/`：共享工具，包括 `app_theme.dart`（主题）、`app_logger.dart`（日志）、`global_config.dart`（全局状态）。
- `lib/services/`：业务服务（VPN 配置、全局代理、权限引导、同步等），与原生操作分离。
- `lib/widgets/`：跨界面复用的小部件，优先复用而非在 `screens/` 内重复布局。
- `lib/l10n/app_localizations.dart`：中英双语字符串表；新增 UI 文案必须在此维护并通过 `context.l10n.get(...)` 读取。
- `go_core/*.go`：FFI 导出函数。所有 `//export` 函数需保持 C 兼容签名，并负责释放由 Go 分配的内存。

---

## 3. 开发约定
### 3.1 通用流程
1. 修改前确认是否已有同类模块可复用，避免重复实现。
2. 所有代码变更必须通过格式化与静态检查：
   - Flutter/Dart：`dart format .`（或 `flutter format`）与 `flutter analyze`。
   - Go：`go fmt ./...` 与必要的 `go test`（若添加测试）。
3. 若改动影响构建流程或原生行为，应在 PR 描述中注明目标平台及验证方式。
4. 文档、脚本或模板的行为改变需同步更新相关 `docs/*.md` 或脚本注释。

### 3.2 Flutter/Dart 代码
- 遵循 `analysis_options.yaml` 中的 lint（基于 `flutter_lints`），避免在全局关闭规则；局部例外请使用 `// ignore` 并附原因。
- UI 组件中的文本必须通过 `context.l10n.get(key)` 获取，确保中英文同步更新。新增键值同时添加 `en` 与 `zh` 译文。
- 复用 `ValueNotifier` 和 `GlobalState` 提供的状态，不直接操作底层服务对象。
- 通过 `addAppLog` 写入日志，禁止直接在生产逻辑中使用 `print`。
- 在与原生交互时，优先使用服务层方法（如 `VpnConfig`, `NativeBridge`）；避免在视图层直接处理文件路径、权限或 FFI 细节。
- 处理异步调用时务必使用 `await` 并捕获错误，界面层应提供用户反馈（SnackBar/Dialog）。

### 3.3 Go FFI 代码
- 每个暴露给 Flutter 的函数都应以字符串或明确的错误码反馈结果；错误信息请保持英文或双语，便于前端显示。
- 所有通过 `C.CString` 或 `C.malloc` 创建的指针必须在 Go 端提供释放方法（参见 `FreeCString`）。Flutter 侧调用后务必释放。
- 平台差异逻辑放在 `bridge_*.go` 中，保持 `bridge.go` 仅负责公共导出函数。
- 在新增系统调用或需要特权操作时，请在 `docs/` 中补充对应平台的部署说明。

### 3.4 资源与模板
- 修改 `lib/templates/` 内文件后，确保对应的 `services/vpn_config_service.dart` 或相关生成逻辑同步更新。
- 新增静态资源（图标、配置示例等）需放置于 `assets/` 并在 `pubspec.yaml` 中登记。
- 若调整默认配置或示例节点，更新 `README.md`、`docs/user-manual.md` 等对外文档。

---

## 4. 构建与测试
- Flutter 应用默认使用 `flutter run` 或平台特定命令进行本地验证，确保关键页面（首页、节点列表、设置、日志）可正常渲染。
- 桌面平台需要验证 `NativeBridge` 写入配置、启动/停止服务的流程，至少使用模拟路径运行到返回结果。
- 更改 Makefile 或构建脚本后，请在 PR 中注明已在对应平台执行的命令（如 `make macos-arm64`、`make windows-x64`）。

---

## 5. 文档与日志
- 新增功能或显著行为更改必须同步更新 `CHANGELOG.md`。
- 面向用户的流程变更，请补充或修改 `docs/` 目录下的相关指南。
- 代码中日志请保持简洁、可检索，并避免泄露敏感信息（密码、UUID 等）。

---

如需在子目录定义额外规范，可在该目录下创建新的 `AGENTS.md`，层级越深优先级越高。
