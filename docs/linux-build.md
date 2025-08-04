# Linux 构建须知

本文档说明如何在 Linux 平台编译 XStream 所需的 `libgo_native_bridge.so` 动态库并构建桌面应用。

## 生成共享库

在仓库根目录执行：

```bash
./build_scripts/build_linux.sh
```

脚本会优先使用与 `flutter` 打包在一起的 `clang/clang++`，以确保编译出的库和桌面应用依赖同一套 glibc。如未找到则退回系统的 `clang`，二者都缺失时脚本会报错终止。

该脚本在 CI 中也会被调用，随后运行以下命令构建桌面应用：

```bash
CC=/snap/flutter/current/usr/bin/clang \
CXX=/snap/flutter/current/usr/bin/clang++ \
flutter build linux --release -v
```

如果 `flutter` 并非以 Snap 形式安装，可将上述路径替换为实际安装目录下的 `clang`/`clang++`，务必保持与 `build_linux.sh` 使用的编译器一致，否则可能出现 `pthread_*` 相关链接错误。

依赖 ImageMagick，若未安装请先安装 `convert` 命令。此外，系统托盘功能依赖 `libayatana-appindicator3-dev`（旧发行版可安装 `libappindicator3-dev`）。若缺失该库，`go build` 会因 `pkg-config` 找不到 `ayatana-appindicator3-0.1` 而报错。
