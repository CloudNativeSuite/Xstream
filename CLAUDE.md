# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

XStream is a cross-platform network accelerator powered by XTLS VLESS. It's a Flutter application with a Go core module that provides a GUI client for managing Xray-core multi-node connections across macOS, Windows, Linux, Android, and iOS.

## Development Commands

### Building and Running
- `flutter pub get` - Install dependencies
- `flutter run -d macos` - Run on macOS in debug mode
- `flutter clean` - Clean build cache
- `make clean` - Clean all build outputs and extended attributes

### Platform-Specific Builds
- `make macos-arm64` - Build macOS ARM64 release with DMG
- `make macos-intel` - Build macOS Intel release with DMG
- `make windows-x64` - Build Windows x64 release
- `make linux-x64` - Build Linux x64 release
- `make android-arm64` - Build Android APK
- `make ios-arm64` - Build iOS release (unsigned)

### Icon Generation
- `make icon` - Generate app icons for all platforms
- `make windows-icon` - Generate Windows-specific icon
- `sh scripts/generate_icons.sh` - Generate iOS app icons

### Linting and Analysis
- `flutter analyze` - Run Dart analyzer
- Analysis configuration in `analysis_options.yaml`

### Testing
- `flutter test` - Run unit tests
- The project uses `flutter_test` framework

## Architecture

### Core Structure
- **Flutter UI Layer**: Dart code in `lib/` handling UI and business logic
- **Go Core Module**: `go_core/` containing Xray-core integration and native bridge
- **Platform Bridges**: Native code for each platform in respective directories

### Key Directories
- `lib/screens/` - UI screens (home, settings, logs, subscription, help, about)
- `lib/services/` - Business logic (VPN config, update checker, telemetry)
- `lib/utils/` - Utilities (theme, config, logging, native bridge)
- `lib/widgets/` - Reusable UI components
- `lib/templates/` - Configuration templates for Xray and system services
- `go_core/` - Go module with Xray-core integration
- Platform-specific dirs (`macos/`, `windows/`, `linux/`, `android/`, `ios/`)

### Native Bridge Architecture
Each platform has native bridge extensions in Swift (iOS/macOS) that handle:
- **ConfigWriter**: Configuration file writing (`writeConfigFiles`, `writeFile`)
- **XrayInit**: Xray initialization with permission handling (`runInitXray`)
- **ServiceControl**: Service management via launchctl/systemctl
- **Logger**: Flutter-native logging bridge (`logToFlutter`)

## Important Dependencies

### Flutter Dependencies
- `provider: ^6.1.5` - State management
- `flutter_localizations` - Internationalization (English/Chinese)
- `path_provider: ^2.1.5` - File system paths
- `process_run: 1.1.0` - Process execution
- `ffi: 2.0.1` - Foreign function interface
- `url_launcher: ^6.3.1` - URL launching
- `shared_preferences: ^2.2.2` - Local storage

### Go Dependencies
- `github.com/xtls/xray-core v1.8.24` - Core networking functionality
- `github.com/getlantern/systray v1.2.2` - System tray integration
- `golang.org/x/sys v0.33.0` - System calls

## Development Notes

### Multi-Platform Considerations
- The app supports Chinese and English localization
- Platform-specific builds have different packaging (DMG for macOS, MSIX for Windows)
- DMG naming follows pattern: `xstream-release-<tag>.dmg` for tagged releases, `xstream-latest-<commit>.dmg` for main branch, `xstream-dev-<commit>.dmg` for feature branches

### macOS Development
- Requires Xcode and CocoaPods
- Uses `xcodebuild` and `create-dmg` for packaging
- Requires macOS network and file access permissions
- Use `make fix-macos-signing` to clean extended attributes before builds

### State Management
- Uses Flutter's `ValueListenableBuilder` pattern
- Global state in `utils/global_config.dart`
- Locale and debug mode managed globally

### FFI Integration
- Go core module compiled as FFI library
- Bindings generated in `lib/bindings/bridge_bindings.dart`
- Native bridge handles platform-specific service management

### Update System
- Automatic update checking via `services/update/`
- Uses Pulp REST API for version queries
- Supports stable and latest channels
- Platform-specific update handling

### Common Issues
- Use `flutter clean` for build cache issues
- Check macOS permissions for network/file access
- Use `xattr -rc .` to clean extended attributes on macOS
- Ensure proper Go toolchain version (1.23.0+)