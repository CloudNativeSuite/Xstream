#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
flutter pub get
flutter pub run msix:build
