# Windows 构建指南

本项目通过 Go 和 Dart FFI 在 Windows 上实现核心功能。构建前需要先编译提供给 Flutter 的 DLL。

## 1. 安装依赖

1. 安装 [Go](https://go.dev/dl/) 1.20+ 并确保 `go` 在 `PATH` 中。
2. 安装 [Flutter](https://docs.flutter.dev/get-started/install/windows) SDK。

## 2. 编译 Go 共享库

在项目根目录执行：

```bash
bash build_scripts/build_windows.sh
```

执行脚本 `build_scripts/build_windows.sh`，脚本会利用 MinGW 工具链将 `go_core` 编译为 `bindings/libbridge.dll`供 FFI 调用使用，生成的 DLL 会被 Dart 通过 `DynamicLibrary.open` 加载。

如遇 `go build` 相关错误，可在 `go_core` 目录手动执行：

```powershell
go env CGO_ENABLED   # 应输出 1
go build -buildmode=c-archive -o libgo_logic.a
```

成功后会生成 `libgo_logic.a` 与 `libgo_logic.h`，随后再运行 `flutter build windows` 即可。

## 3. 构建 Flutter 桌面应用

```
flutter clean
flutter pub get
flutter build windows
```

构建前请确保已执行上一步生成 `libbridge.dll`，否则应用无法加载共享库。


## 4. Release Packaging

GitHub Actions will compress the entire `build/windows/x64/runner/Release`
directory into `xstream-windows.zip` for distribution. The archive includes
`flutter_windows.dll` so the application can run on systems without Flutter
installed.

## 5. 打包 MSIX 以便上架 Microsoft Store

项目现已支持通过 [msix](https://pub.dev/packages/msix) 插件生成可上架
Microsoft Store 的安装包。只需在 Windows 环境执行脚本：

```powershell
./build_scripts/package_windows_msix.ps1
```

脚本会根据根目录下的 `msix_config.yaml` 创建 `.msix` 文件，生成的安装包
将位于 `build/windows/x64/runner/Release/` 目录下。
